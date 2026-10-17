import logging
import uuid
from collections import OrderedDict
from typing import Any, List, Optional

from ..models.schemas import (
    Quiz, QuizQuestion, QuizSubmissionRequest, QuizResultResponse, QuestionEvaluation
)
from ..services.groq_service import groq_service, AIServiceError
from ..services.rag_service import rag_service

logger = logging.getLogger(__name__)


class QuizNotFoundError(KeyError):
    """Raised when a submission references a quiz this server no longer holds."""


def _validate_quiz_payload(data: Any) -> Optional[str]:
    if not isinstance(data, dict):
        return "Top-level value must be a JSON object."
    questions = data.get("questions")
    if not isinstance(questions, list) or not (4 <= len(questions) <= 8):
        return "'questions' must contain 4 to 8 questions."
    for i, q in enumerate(questions, start=1):
        if not isinstance(q, dict) or not str(q.get("question", "")).strip():
            return f"Question {i} is missing its text."
        options = q.get("options")
        if not isinstance(options, list) or len(options) != 4 or not all(str(o).strip() for o in options):
            return f"Question {i} must have exactly 4 non-empty options."
        if len({str(o).strip().lower() for o in options}) != 4:
            return f"Question {i} has duplicate options."
        idx = q.get("correct_option_index")
        if not isinstance(idx, int) or not (0 <= idx <= 3):
            return f"Question {i} needs an integer correct_option_index between 0 and 3."
        if not str(q.get("explanation", "")).strip():
            return f"Question {i} is missing an explanation."
    return None


class AdaptiveQuizAgent:
    """Generates grounded module assessments and gives AI coaching on the results."""

    MAX_STORED_QUIZZES = 500

    def __init__(self):
        self.quiz_store: "OrderedDict[str, Quiz]" = OrderedDict()

    def generate_quiz_for_module(self, syllabus_id: str, topic: str, module_id: str, module_title: str) -> Quiz:
        quiz_id = f"quiz_{module_id}_{uuid.uuid4().hex[:8]}"
        logger.info(f"Generating quiz for module '{module_title}' (Topic: {topic})")

        rag_hits = rag_service.search_relevant_chunks(topic, f"{topic} {module_title}", top_k=4) \
            or rag_service.search_relevant_chunks(syllabus_id, f"{topic} {module_title}", top_k=4)
        context_str = "\n".join(f"- {h['content'][:400]}" for h in rag_hits) or "(none)"

        system_prompt = (
            "You are an expert examiner. Write a 5-question multiple-choice quiz that checks genuine "
            f"understanding of the module '{module_title}' in the course '{topic}'.\n"
            "Rules:\n"
            "- Mix recall, application (scenario-based) and reasoning questions.\n"
            "- Exactly 4 options per question; one unambiguously correct; distractors plausible.\n"
            "- Vary the position of the correct answer across questions.\n"
            "- Explanations say why the answer is right AND why the main distractor is wrong.\n"
            "Output JSON:\n"
            "{\n"
            '  "questions": [\n'
            '    {"question": "string", "options": ["A", "B", "C", "D"], "correct_option_index": 0,\n'
            '     "concept_tested": "string", "explanation": "string"}\n'
            "  ]\n"
            "}"
        )
        user_prompt = f"Module: {module_title}\nCourse: {topic}\nReference material:\n{context_str}"
        data = groq_service.generate_json_response(
            system_prompt, user_prompt, temperature=0.4, validator=_validate_quiz_payload
        )

        questions: List[QuizQuestion] = [
            QuizQuestion(
                id=f"q_{idx + 1}",
                question=str(q["question"]).strip(),
                options=[str(o).strip() for o in q["options"]],
                correct_option_index=q["correct_option_index"],
                explanation=str(q["explanation"]).strip(),
                concept_tested=str(q.get("concept_tested") or module_title).strip(),
            )
            for idx, q in enumerate(data["questions"])
        ]

        quiz = Quiz(
            id=quiz_id,
            syllabus_id=syllabus_id,
            module_id=module_id,
            module_title=module_title,
            questions=questions,
            passing_score_percentage=70,
        )

        self.quiz_store[quiz_id] = quiz
        while len(self.quiz_store) > self.MAX_STORED_QUIZZES:
            self.quiz_store.popitem(last=False)
        return quiz

    def evaluate_quiz(self, submission: QuizSubmissionRequest) -> QuizResultResponse:
        quiz = self.quiz_store.get(submission.quiz_id)
        if not quiz:
            raise QuizNotFoundError(submission.quiz_id)

        total_questions = len(quiz.questions)
        correct_count = 0
        evaluations: List[QuestionEvaluation] = []
        missed: List[QuizQuestion] = []

        for q in quiz.questions:
            user_ans = submission.selected_answers.get(q.id, -1)
            is_correct = user_ans == q.correct_option_index
            if is_correct:
                correct_count += 1
            else:
                missed.append(q)

            evaluations.append(QuestionEvaluation(
                question_id=q.id,
                is_correct=is_correct,
                user_answer_index=user_ans,
                correct_answer_index=q.correct_option_index,
                explanation=q.explanation,
                remediation_recommendation=(
                    None if is_correct else f"Revisit '{q.concept_tested}' in this module's lessons."
                ),
            ))

        score_percentage = (correct_count / total_questions) * 100 if total_questions else 0.0
        passed = score_percentage >= quiz.passing_score_percentage

        return QuizResultResponse(
            quiz_id=quiz.id,
            score_percentage=round(score_percentage, 1),
            passed=passed,
            correct_count=correct_count,
            total_questions=total_questions,
            evaluations=evaluations,
            ai_coaching_feedback=self._coaching(quiz, score_percentage, passed, missed, submission),
        )

    @staticmethod
    def _coaching(quiz: Quiz, score: float, passed: bool, missed: List[QuizQuestion],
                  submission: QuizSubmissionRequest) -> str:
        summary = (
            f"You scored {round(score)}% on '{quiz.module_title}' "
            f"({'passed' if passed else f'pass mark {quiz.passing_score_percentage}%'})."
        )
        if not missed:
            return summary + " Every answer was correct — the next module is unlocked."

        missed_desc = "\n".join(
            f"- Q: {q.question}\n  Student chose: "
            f"{q.options[submission.selected_answers[q.id]] if 0 <= submission.selected_answers.get(q.id, -1) < len(q.options) else 'no answer'}\n"
            f"  Correct: {q.options[q.correct_option_index]}"
            for q in missed
        )
        try:
            advice = groq_service.generate_text_response(
                "You are a supportive tutor. In under 120 words, diagnose the misconceptions behind the "
                "student's wrong answers and give 2-3 concrete next steps. Plain Markdown, no headings.",
                f"Module: {quiz.module_title}\nMissed questions:\n{missed_desc}",
                temperature=0.4, max_tokens=600,
            )
            return f"{summary}\n\n{advice}"
        except AIServiceError as exc:
            logger.warning(f"Coaching generation failed: {exc}")
            concepts = ", ".join(sorted({q.concept_tested for q in missed}))
            return f"{summary} Review: {concepts}."


quiz_agent = AdaptiveQuizAgent()
