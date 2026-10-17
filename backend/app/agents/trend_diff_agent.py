import json
import logging
import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any, List, Optional

from ..models.schemas import (
    SyncTrendsRequest, SyncTrendsResponse, TrendUpdate, Subtopic, ResourceItem, ResourceType
)
from ..services.scraper_service import scraper_service
from ..services.groq_service import groq_service

logger = logging.getLogger(__name__)


def _validate_trend_payload(data: Any) -> Optional[str]:
    if not isinstance(data, dict) or not isinstance(data.get("found"), bool):
        return "Must be an object with a boolean 'found'."
    if data["found"]:
        for key in ("detected_trend_title", "summary", "subtopic_title", "subtopic_description"):
            if not str(data.get(key, "")).strip():
                return f"Missing '{key}'."
        idx = data.get("source_index")
        if not isinstance(idx, int):
            return "'source_index' must be an integer pointing at the supporting source."
        mod = data.get("target_module_number")
        if not isinstance(mod, int):
            return "'target_module_number' must be an integer."
    return None


class TrendDiffEngineAgent:
    """
    Compares live web results against the current syllabus and proposes an
    addition only when there is a genuinely new, source-backed development.
    """

    def sync_trends_for_syllabus(self, req: SyncTrendsRequest) -> SyncTrendsResponse:
        topic = req.topic
        logger.info(f"Checking live web trends for topic: {topic}")

        with ThreadPoolExecutor(max_workers=2) as pool:
            web_f = pool.submit(scraper_service.search_web_trends, topic, 6)
            papers_f = pool.submit(scraper_service.search_arxiv_papers, topic, 3)
            web_results = web_f.result()
            papers = papers_f.result()

        sources: List[ResourceItem] = [
            ResourceItem(
                id=f"trend_{uuid.uuid4().hex[:6]}",
                title=r["title"], type=ResourceType.ARTICLE, url=r["url"],
                snippet=r["snippet"], source_name=r.get("source", "Web"),
            )
            for r in web_results if r.get("url")
        ] + list(papers)

        if not sources:
            return SyncTrendsResponse(
                syllabus_id=req.syllabus_id,
                new_trends_found=False,
                updates=[],
                update_message="Couldn't reach live sources right now. Try syncing again later.",
            )

        numbered = [
            {"index": i, "title": s.title, "snippet": s.snippet[:250]} for i, s in enumerate(sources)
        ]
        system_prompt = (
            "You keep a course syllabus current. Compare the syllabus modules with the fresh sources. "
            "Only report a trend if a source describes a genuinely new or important development that the "
            "syllabus does not already cover. Ignore SEO listicles and generic content. "
            "If nothing qualifies, return {\"found\": false}.\n"
            "Otherwise output JSON:\n"
            "{\n"
            '  "found": true,\n'
            '  "detected_trend_title": "string",\n'
            '  "summary": "1-2 sentences",\n'
            '  "subtopic_title": "string",\n'
            '  "subtopic_description": "string",\n'
            '  "estimated_minutes": 20,\n'
            '  "target_module_number": 1,\n'
            '  "source_index": 0\n'
            "}"
        )
        modules_desc = "\n".join(f"{i + 1}. {t}" for i, t in enumerate(req.current_module_titles))
        user_prompt = (
            f"Course: {topic}\nSyllabus modules:\n{modules_desc}\n\n"
            f"Fresh sources:\n{json.dumps(numbered, ensure_ascii=False)}"
        )

        data = groq_service.generate_json_response(
            system_prompt, user_prompt, temperature=0.2, max_tokens=1500,
            validator=_validate_trend_payload,
        )

        if not data["found"]:
            return SyncTrendsResponse(
                syllabus_id=req.syllabus_id,
                new_trends_found=False,
                updates=[],
                update_message="Your syllabus already covers the latest developments.",
            )

        src_idx = data["source_index"]
        trend_sources = [sources[src_idx]] if 0 <= src_idx < len(sources) else []
        mod_num = data["target_module_number"]
        mod_num = min(max(mod_num, 1), max(len(req.current_module_titles), 1))

        try:
            minutes = max(5, min(int(data.get("estimated_minutes", 20)), 120))
        except (TypeError, ValueError):
            minutes = 20

        new_subtopic = Subtopic(
            id=f"trend_sub_{uuid.uuid4().hex[:6]}",
            title=str(data["subtopic_title"]).strip(),
            description=str(data["subtopic_description"]).strip(),
            estimated_minutes=minutes,
            resources=trend_sources,
            is_trend_updated=True,
            trend_note="Added from a recent web source",
        )

        title = str(data["detected_trend_title"]).strip()
        return SyncTrendsResponse(
            syllabus_id=req.syllabus_id,
            new_trends_found=True,
            updates=[TrendUpdate(
                detected_trend_title=title,
                summary=str(data["summary"]).strip(),
                affected_module_id=f"mod_{mod_num}",
                suggested_subtopic_addition=new_subtopic,
                sources=trend_sources,
            )],
            update_message=f"New development found: '{title}'.",
        )


trend_diff_agent = TrendDiffEngineAgent()
