from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from enum import Enum
from datetime import datetime

class LearningStyle(str, Enum):
    CHAT_TUTOR = "chat_tutor"
    VIDEO_LECTURE = "video_lecture"
    DEEP_ARTICLE = "deep_article"
    RESEARCH_PAPER = "research_paper"
    HANDS_ON = "hands_on"
    BALANCED_HYBRID = "balanced_hybrid"

class ExperienceLevel(str, Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"
    EXPERT = "expert"

class ResourceType(str, Enum):
    VIDEO = "video"
    ARTICLE = "article"
    PAPER = "paper"
    DOCUMENTATION = "documentation"
    COURSE = "course"

class ResourceItem(BaseModel):
    id: str
    title: str
    type: ResourceType
    url: str
    snippet: str
    source_name: str
    author_or_channel: Optional[str] = None
    published_date: Optional[str] = None
    key_takeaways: List[str] = Field(default_factory=list)

class Subtopic(BaseModel):
    id: str
    title: str
    description: str
    estimated_minutes: int = 15
    resources: List[ResourceItem] = Field(default_factory=list)
    is_completed: bool = False
    is_trend_updated: bool = False
    trend_note: Optional[str] = None

class Module(BaseModel):
    id: str
    title: str
    summary: str
    learning_objectives: List[str] = Field(default_factory=list)
    order_index: int
    subtopics: List[Subtopic]
    quiz_id: Optional[str] = None
    is_unlocked: bool = True
    is_passed: bool = False

class Syllabus(BaseModel):
    id: str
    topic: str
    user_experience_level: ExperienceLevel
    primary_learning_style: LearningStyle
    industry_standards_summary: str
    prerequisites: List[str] = Field(default_factory=list)
    learning_outcomes: List[str] = Field(default_factory=list)
    latest_trends_identified: List[str] = Field(default_factory=list)
    modules: List[Module]
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class GenerateSyllabusRequest(BaseModel):
    topic: str
    experience_level: ExperienceLevel = ExperienceLevel.BEGINNER
    preferred_learning_style: LearningStyle = LearningStyle.BALANCED_HYBRID
    goals_or_focus_areas: Optional[str] = None

class SyncTrendsRequest(BaseModel):
    syllabus_id: str
    topic: str
    current_module_titles: List[str]

class TrendUpdate(BaseModel):
    detected_trend_title: str
    summary: str
    affected_module_id: Optional[str] = None
    suggested_subtopic_addition: Optional[Subtopic] = None
    sources: List[ResourceItem] = Field(default_factory=list)

class SyncTrendsResponse(BaseModel):
    syllabus_id: str
    new_trends_found: bool
    updates: List[TrendUpdate] = Field(default_factory=list)
    update_message: str

class Flashcard(BaseModel):
    id: str
    question: str
    answer: str
    key_concept: str = Field(default="Core Concept", alias="keyConcept")
    code_snippet: Optional[str] = None
    is_mastered: bool = False

    model_config = {"populate_by_name": True}


class TopicLessonContent(BaseModel):
    subtopic_id: str
    title: str
    module_title: str
    format: LearningStyle
    core_markdown_content: str
    socratic_dialogue: List[Dict[str, str]] = Field(default_factory=list)
    recommended_videos: List[ResourceItem] = Field(default_factory=list)
    research_papers: List[ResourceItem] = Field(default_factory=list)
    curated_articles: List[ResourceItem] = Field(default_factory=list)
    code_snippets: List[Dict[str, str]] = Field(default_factory=list)
    key_cheat_sheet_points: List[str] = Field(default_factory=list)
    flashcards: List[Flashcard] = Field(default_factory=list)

class StudentAnalytics(BaseModel):
    total_study_minutes: int = 0
    streak_days: int = 0
    xp_points: int = 0
    total_quizzes_taken: int = 0
    total_quizzes_passed: int = 0
    average_quiz_score: float = 0.0
    mastered_skills: List[str] = Field(default_factory=list)

class TutorChatRequest(BaseModel):
    topic: str
    subtopic_title: str
    lesson_context: str
    student_message: str
    chat_history: List[Dict[str, str]] = Field(default_factory=list)
    preferred_style: LearningStyle = LearningStyle.CHAT_TUTOR

class TutorChatResponse(BaseModel):
    reply_markdown: str
    suggested_followup_questions: List[str] = Field(default_factory=list)
    cited_resources: List[ResourceItem] = Field(default_factory=list)

class QuizQuestion(BaseModel):
    id: str
    question: str
    options: List[str]
    correct_option_index: int
    explanation: str
    concept_tested: str
    reference_note: Optional[str] = None

class Quiz(BaseModel):
    id: str
    syllabus_id: str
    module_id: str
    module_title: str
    questions: List[QuizQuestion]
    passing_score_percentage: int = 75

class QuizSubmissionRequest(BaseModel):
    quiz_id: str
    selected_answers: Dict[str, int] # question_id -> chosen index

class QuestionEvaluation(BaseModel):
    question_id: str
    is_correct: bool
    user_answer_index: int
    correct_answer_index: int
    explanation: str
    remediation_recommendation: Optional[str] = None

class QuizResultResponse(BaseModel):
    quiz_id: str
    score_percentage: float
    passed: bool
    correct_count: int
    total_questions: int
    evaluations: List[QuestionEvaluation]
    ai_coaching_feedback: str
