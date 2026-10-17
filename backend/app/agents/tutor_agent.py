import logging
import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict, List, Optional

from ..models.schemas import (
    TopicLessonContent, TutorChatRequest, TutorChatResponse,
    LearningStyle, ResourceItem, ResourceType, Flashcard
)
from ..services.groq_service import groq_service
from ..services.youtube_service import youtube_service
from ..services.scraper_service import scraper_service
from ..services.rag_service import rag_service

logger = logging.getLogger(__name__)

# How many prior chat turns are sent back to the model for context.
_MAX_HISTORY_TURNS = 12


def _validate_lesson_extras(data: Any) -> Optional[str]:
    if not isinstance(data, dict):
        return "Top-level value must be a JSON object."
    cards = data.get("flashcards")
    if not isinstance(cards, list) or len(cards) < 3:
        return "'flashcards' must contain at least 3 cards."
    for i, c in enumerate(cards, start=1):
        if not isinstance(c, dict) or not c.get("question") or not c.get("answer"):
            return f"Flashcard {i} needs both 'question' and 'answer'."
    sheet = data.get("key_cheat_sheet_points")
    if not isinstance(sheet, list) or len(sheet) < 3:
        return "'key_cheat_sheet_points' must contain at least 3 points."
    dialogue = data.get("socratic_dialogue")
    if not isinstance(dialogue, list) or len(dialogue) < 2:
        return "'socratic_dialogue' must contain at least 2 turns."
    for i, turn in enumerate(dialogue, start=1):
        if not isinstance(turn, dict) or turn.get("speaker") not in ("tutor", "student") or not turn.get("text"):
            return f"Dialogue turn {i} needs 'speaker' ('tutor'|'student') and 'text'."
    if not isinstance(data.get("code_snippets", []), list):
        return "'code_snippets' must be a list (empty if not applicable)."
    return None


def _validate_chat_reply(data: Any) -> Optional[str]:
    if not isinstance(data, dict) or not str(data.get("reply_markdown", "")).strip():
        return "Missing non-empty 'reply_markdown'."
    if not isinstance(data.get("follow_up_questions", []), list):
        return "'follow_up_questions' must be a list."
    return None


class ContentSynthesizerAgent:
    """
    Synthesizes multimodal learning content and answers student questions,
    grounded in live web resources. All teaching content is AI-generated.
    """

    def get_lesson_content(self, topic: str, module_title: str, subtopic_title: str, style: LearningStyle) -> TopicLessonContent:
        logger.info(f"Generating lesson content for: {subtopic_title} in {topic} (Style: {style.value})")
        query = f"{topic} {subtopic_title}"

        with ThreadPoolExecutor(max_workers=5) as pool:
            videos_f = pool.submit(self._safe, youtube_service.search_learning_videos, query, 3)
            papers_f = pool.submit(self._safe, scraper_service.search_arxiv_papers, query, 2)
            articles_f = pool.submit(self._safe, scraper_service.search_articles_and_docs, query, 3)
            markdown_f = pool.submit(self._generate_lesson_markdown, topic, module_title, subtopic_title, style)
            extras_f = pool.submit(self._generate_lesson_extras, topic, module_title, subtopic_title)

            videos = videos_f.result()
            papers = papers_f.result()
            articles = articles_f.result()
            # AI failures propagate (AIServiceError) — no placeholder lessons.
            markdown_content = markdown_f.result()
            extras = extras_f.result()

        # Make the lesson searchable for the chat tutor.
        rag_service.add_lesson(topic, subtopic_title, markdown_content, videos + papers + articles)

        flashcards = [
            Flashcard(
                id=f"fc_{uuid.uuid4().hex[:8]}",
                question=str(c["question"]).strip(),
                answer=str(c["answer"]).strip(),
                key_concept=str(c.get("key_concept") or subtopic_title).strip(),
                code_snippet=(str(c["code_snippet"]).strip() if c.get("code_snippet") else None),
            )
            for c in extras["flashcards"]
        ]
        code_snippets = [
            {
                "language": str(s.get("language", "text")),
                "title": str(s.get("title", subtopic_title)),
                "code": str(s.get("code", "")),
            }
            for s in extras.get("code_snippets", [])
            if isinstance(s, dict) and str(s.get("code", "")).strip()
        ]

        return TopicLessonContent(
            subtopic_id=f"sub_{subtopic_title.lower().replace(' ', '_')}",
            title=subtopic_title, module_title=module_title, format=style,
            core_markdown_content=markdown_content,
            socratic_dialogue=[
                {"speaker": t["speaker"], "text": str(t["text"]).strip()}
                for t in extras["socratic_dialogue"]
            ],
            recommended_videos=videos, research_papers=papers, curated_articles=articles,
            code_snippets=code_snippets,
            key_cheat_sheet_points=[str(p).strip() for p in extras["key_cheat_sheet_points"] if str(p).strip()],
            flashcards=flashcards,
        )

    def answer_student_doubt(self, req: TutorChatRequest) -> TutorChatResponse:
        logger.info(f"Answering student doubt on {req.subtopic_title}: {req.student_message}")

        rag_hits = rag_service.search_relevant_chunks(req.topic, req.student_message, top_k=4)
        rag_context = "\n".join(
            f"[{i + 1}] {h['metadata'].get('title', 'Reference')}: {h['content'][:600]}"
            for i, h in enumerate(rag_hits)
        ) or "(no indexed references)"

        system_prompt = (
            "You are Learnly's AI tutor — patient, precise and encouraging. "
            f"The student is studying '{req.subtopic_title}' within '{req.topic}'. "
            f"Their preferred learning style is '{req.preferred_style.value}'.\n"
            "How to answer:\n"
            "- Answer the actual question directly first, then explain why.\n"
            "- Use concrete examples, and code blocks when the topic is technical.\n"
            "- Use the reference material when relevant; if it doesn't cover the question, rely on "
            "well-established knowledge and say so when you're unsure. Never fabricate citations.\n"
            "- Keep it focused: usually 120-350 words of GitHub-flavoured Markdown.\n"
            "Output JSON: {\"reply_markdown\": \"string\", "
            "\"follow_up_questions\": [\"2-3 short questions the student might ask next\"], "
            "\"used_reference_numbers\": [1]}"
        )

        messages: List[Dict[str, str]] = []
        for turn in req.chat_history[-_MAX_HISTORY_TURNS:]:
            role = "assistant" if turn.get("role") in ("tutor", "assistant") else "user"
            content = str(turn.get("content", "")).strip()
            if content:
                messages.append({"role": role, "content": content[:2000]})
        # Drop a trailing copy of the current question if the client already included it.
        if messages and messages[-1]["role"] == "user" and messages[-1]["content"] == req.student_message.strip():
            messages.pop()

        history_text = "\n".join(f"{m['role']}: {m['content']}" for m in messages)
        user_prompt = (
            f"Lesson excerpt:\n{req.lesson_context[:2500]}\n\n"
            f"Reference material:\n{rag_context}\n\n"
            f"Conversation so far:\n{history_text or '(none)'}\n\n"
            f"Student's new question: {req.student_message}"
        )

        data = groq_service.generate_json_response(
            system_prompt, user_prompt, temperature=0.5, max_tokens=3000,
            validator=_validate_chat_reply,
        )

        used = {n for n in data.get("used_reference_numbers", []) if isinstance(n, int)}
        cited: List[ResourceItem] = []
        for i, hit in enumerate(rag_hits, start=1):
            url = hit["metadata"].get("url")
            if i in used and url:
                cited.append(ResourceItem(
                    id=f"cite_{i}_{abs(hash(url)) % 100000}",
                    title=hit["metadata"].get("title", "Reference"),
                    type=self._resource_type(hit["metadata"].get("type")),
                    url=url,
                    snippet=hit["content"][:200],
                    source_name=hit["metadata"].get("source", "Web"),
                ))

        return TutorChatResponse(
            reply_markdown=str(data["reply_markdown"]).strip(),
            suggested_followup_questions=[
                str(q).strip() for q in data.get("follow_up_questions", []) if str(q).strip()
            ][:3],
            cited_resources=cited,
        )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _generate_lesson_markdown(topic: str, module_title: str, subtopic_title: str, style: LearningStyle) -> str:
        system_prompt = (
            "You are a world-class teacher writing one focused lesson. "
            f"Teach '{subtopic_title}' (module '{module_title}', course '{topic}'). "
            f"Adapt the presentation to the student's preferred style: {style.value}.\n"
            "Structure (GitHub Markdown):\n"
            "1. A one-paragraph intuition / mental model.\n"
            "2. Core explanation with headings, building from simple to nuanced.\n"
            "3. A worked example (with code blocks if the topic is technical).\n"
            "4. Common mistakes and how to avoid them.\n"
            "5. A 3-bullet recap.\n"
            "Be accurate and current; do not invent APIs, versions or statistics."
        )
        return groq_service.generate_text_response(
            system_prompt, f"Write the lesson on '{subtopic_title}'.", temperature=0.5, max_tokens=5000
        )

    @staticmethod
    def _generate_lesson_extras(topic: str, module_title: str, subtopic_title: str) -> Dict[str, Any]:
        system_prompt = (
            "You create study material for one lesson. "
            f"Lesson: '{subtopic_title}' (module '{module_title}', course '{topic}').\n"
            "Output JSON with this exact schema:\n"
            "{\n"
            '  "socratic_dialogue": [{"speaker": "tutor"|"student", "text": "string"}],  // 4-6 turns, starts with tutor, ends with an open question from the tutor\n'
            '  "key_cheat_sheet_points": ["string"],  // 4-6 crisp, specific facts or rules\n'
            '  "flashcards": [{"question": "string", "answer": "string", "key_concept": "string", "code_snippet": "string or null"}],  // 5-8 cards testing understanding, not trivia\n'
            '  "code_snippets": [{"language": "string", "title": "string", "code": "string"}]  // 1-2 runnable examples if technical, else []\n'
            "}"
        )
        return groq_service.generate_json_response(
            system_prompt, f"Create the study material for '{subtopic_title}'.",
            validator=_validate_lesson_extras,
        )

    @staticmethod
    def _safe(fn, query: str, max_results: int) -> List[ResourceItem]:
        try:
            return fn(query, max_results=max_results)
        except Exception as exc:
            logger.warning(f"Resource search failed for '{query}': {exc}")
            return []

    @staticmethod
    def _resource_type(value: Optional[str]) -> ResourceType:
        try:
            return ResourceType(value)
        except (ValueError, TypeError):
            return ResourceType.ARTICLE


tutor_agent = ContentSynthesizerAgent()
