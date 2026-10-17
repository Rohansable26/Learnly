from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from ..models.schemas import (
    GenerateSyllabusRequest, Syllabus,
    SyncTrendsRequest, SyncTrendsResponse,
    TopicLessonContent, LearningStyle,
    TutorChatRequest, TutorChatResponse,
    Quiz, QuizSubmissionRequest, QuizResultResponse,
    ResourceItem
)
from ..agents.syllabus_agent import syllabus_agent
from ..agents.trend_diff_agent import trend_diff_agent
from ..agents.tutor_agent import tutor_agent
from ..agents.quiz_agent import quiz_agent
from ..services.youtube_service import youtube_service
from ..services.groq_service import groq_service, AIServiceError
from ..agents.quiz_agent import QuizNotFoundError

router = APIRouter()

@router.post("/syllabus/generate", response_model=Syllabus)
def generate_syllabus(req: GenerateSyllabusRequest):
    """
    Generates a personalized, industry-standard syllabus with attached multi-modal resources
    and web trend insights.
    """
    try:
        return syllabus_agent.generate_syllabus(req)
    except AIServiceError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Syllabus generation failed: {str(e)}")

@router.post("/syllabus/sync-trends", response_model=SyncTrendsResponse)
def sync_trends(req: SyncTrendsRequest):
    """
    Scrapes real-time web advancements, comparing them against the current syllabus
    to suggest novel additions.
    """
    try:
        return trend_diff_agent.sync_trends_for_syllabus(req)
    except AIServiceError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Trend synchronization failed: {str(e)}")

@router.get("/learn/lesson", response_model=TopicLessonContent)
def get_lesson(
    topic: str = Query(..., description="Topic name"),
    module_title: str = Query(..., description="Module title"),
    subtopic_title: str = Query(..., description="Subtopic title"),
    style: LearningStyle = Query(LearningStyle.BALANCED_HYBRID, description="Preferred learning style")
):
    """
    Retrieves synthesized multi-modal lesson content tailored to the student's chosen format.
    """
    try:
        return tutor_agent.get_lesson_content(topic, module_title, subtopic_title, style)
    except AIServiceError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lesson synthesis failed: {str(e)}")

@router.post("/learn/chat-tutor", response_model=TutorChatResponse)
def chat_with_tutor(req: TutorChatRequest):
    """
    Conversational RAG assistant grounded in lesson content and live web resources.
    """
    try:
        return tutor_agent.answer_student_doubt(req)
    except AIServiceError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat tutor failed: {str(e)}")

@router.get("/quiz/module", response_model=Quiz)
def get_module_quiz(
    syllabus_id: str = Query(..., description="Syllabus ID"),
    topic: str = Query(..., description="Topic name"),
    module_id: str = Query(..., description="Module ID"),
    module_title: str = Query(..., description="Module title")
):
    """
    Generates an adaptive diagnostic quiz for the end of the module.
    """
    try:
        return quiz_agent.generate_quiz_for_module(syllabus_id, topic, module_id, module_title)
    except AIServiceError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quiz generation failed: {str(e)}")

@router.post("/quiz/submit", response_model=QuizResultResponse)
def submit_quiz(req: QuizSubmissionRequest):
    """
    Evaluates student answers, calculates mastery score, and provides diagnostic AI coaching.
    """
    try:
        return quiz_agent.evaluate_quiz(req)
    except QuizNotFoundError:
        raise HTTPException(status_code=404, detail="Quiz not found (the server may have restarted).")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quiz evaluation failed: {str(e)}")

# ---------------------------------------------------------------------------
# YouTube video search
# ---------------------------------------------------------------------------

@router.get("/videos/search", response_model=List[ResourceItem])
@router.get("/videos/youtube", response_model=List[ResourceItem])
def search_videos(
    query: str = Query(..., description="Learning topic or concept to search"),
    max_results: int = Query(4, ge=1, le=10, description="Number of videos to return (1-10)"),
    language: str = Query("en", description="ISO 639-1 language code (e.g. 'en', 'hi')"),
):
    """
    Search YouTube for high-quality learning videos via the YouTube Data API v3.

    Automatically falls back to DuckDuckGo video search when no YouTube API key
    is configured. Returns an empty list when nothing can be found.

    **Setup**: Add `YOUTUBE_API_KEY=AIza...` to your `.env` file.
    Get a free key at https://console.cloud.google.com/ (YouTube Data API v3).
    """
    try:
        return youtube_service.search_learning_videos(
            query=query,
            max_results=max_results,
            language_code=language,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"YouTube video search failed: {exc}")


# ---------------------------------------------------------------------------
# AI provider status
# ---------------------------------------------------------------------------

@router.get("/ai/info")
def get_ai_info():
    """
    Returns the current AI provider configuration — which services are active
    and which model is in use. Useful for debugging and the settings screen.
    """
    groq_info = groq_service.get_model_info()
    return {
        "primary_provider": "Groq Cloud (Dedicated)",
        "groq": groq_info,
        "youtube": {
            "api_key_set": bool(youtube_service.api_key),
            "mode": "YouTube Data API v3" if youtube_service.api_key else "DuckDuckGo fallback",
            "docs": "https://console.cloud.google.com/",
        },
    }
