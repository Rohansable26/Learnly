import json
import logging
import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict, List, Optional

from ..models.schemas import (
    Syllabus, Module, Subtopic, ResourceItem, GenerateSyllabusRequest
)
from ..services.scraper_service import scraper_service
from ..services.youtube_service import youtube_service
from ..services.groq_service import groq_service
from ..services.rag_service import rag_service

logger = logging.getLogger(__name__)


def _validate_syllabus_payload(data: Any) -> Optional[str]:
    """Return None if the AI payload is a usable syllabus, else a description of the problem."""
    if not isinstance(data, dict):
        return "Top-level value must be a JSON object."
    if not str(data.get("industry_standards_summary", "")).strip():
        return "Missing 'industry_standards_summary'."
    modules = data.get("modules")
    if not isinstance(modules, list) or not (3 <= len(modules) <= 8):
        return "'modules' must be a list of 3 to 8 modules."
    for m_idx, mod in enumerate(modules, start=1):
        if not isinstance(mod, dict) or not str(mod.get("title", "")).strip():
            return f"Module {m_idx} is missing a title."
        if not str(mod.get("summary", "")).strip():
            return f"Module {m_idx} is missing a summary."
        subs = mod.get("subtopics")
        if not isinstance(subs, list) or not (2 <= len(subs) <= 6):
            return f"Module {m_idx} must have 2 to 6 subtopics."
        for s_idx, sub in enumerate(subs, start=1):
            if not isinstance(sub, dict) or not str(sub.get("title", "")).strip():
                return f"Module {m_idx} subtopic {s_idx} is missing a title."
            if not str(sub.get("description", "")).strip():
                return f"Module {m_idx} subtopic {s_idx} is missing a description."
    return None


def _as_str_list(value: Any, limit: int = 8) -> List[str]:
    if not isinstance(value, list):
        return []
    return [str(v).strip() for v in value if str(v).strip()][:limit]


def _as_minutes(value: Any) -> int:
    try:
        return max(5, min(int(value), 180))
    except (TypeError, ValueError):
        return 20


class SyllabusArchitectAgent:
    """
    Constructs a modern, industry-standard curriculum grounded in live web
    research, then attaches real per-module resources (videos, articles, papers).
    """

    def generate_syllabus(self, req: GenerateSyllabusRequest) -> Syllabus:
        topic = req.topic.strip()
        logger.info(f"Generating syllabus for topic: {topic} (Level: {req.experience_level})")

        # 1. Gather live research context in parallel.
        with ThreadPoolExecutor(max_workers=3) as pool:
            trends_f = pool.submit(scraper_service.search_web_trends, topic, 6)
            papers_f = pool.submit(scraper_service.search_arxiv_papers, topic, 3)
            docs_f = pool.submit(scraper_service.search_articles_and_docs, topic, 4)
            web_trends = trends_f.result()
            papers = papers_f.result()
            docs = docs_f.result()

        research_context = [
            {"title": t["title"], "snippet": t["snippet"][:200]} for t in web_trends
        ] + [
            {"title": d.title, "snippet": d.snippet[:200]} for d in docs
        ]

        # 2. Ask the model for a validated curriculum.
        system_prompt = (
            "You are a Lead Curriculum Architect who designs rigorous, practical, up-to-date courses. "
            "Design a syllabus that takes the student from their current level to real competence in the topic. "
            "Rules:\n"
            "- 4 to 6 sequential modules that build on each other; 3 to 4 concrete subtopics per module.\n"
            "- Calibrate depth to the student's experience level — skip what they already know, do not pad.\n"
            "- Subtopic titles must be specific and teachable (e.g. 'Writing your first async generator', "
            "not 'Advanced concepts').\n"
            "- Respect the student's goals. Use the research context to reflect current practice, "
            "but never invent tools, versions, or papers.\n"
            "- estimated_minutes is a realistic study time for one subtopic (10-90).\n"
            "Output JSON with this exact schema:\n"
            "{\n"
            '  "industry_standards_summary": "2-3 sentences on what competence in this topic looks like today",\n'
            '  "prerequisites": ["string"],\n'
            '  "learning_outcomes": ["what the student will be able to do after the course"],\n'
            '  "latest_trends": ["short names of genuinely current developments, from the research context"],\n'
            '  "modules": [\n'
            "    {\n"
            '      "title": "string (no leading number)",\n'
            '      "summary": "string",\n'
            '      "learning_objectives": ["string"],\n'
            '      "subtopics": [\n'
            '        {"title": "string", "description": "string", "estimated_minutes": 20}\n'
            "      ]\n"
            "    }\n"
            "  ]\n"
            "}"
        )
        user_prompt = (
            f"Topic: {topic}\n"
            f"Student experience level: {req.experience_level.value}\n"
            f"Preferred learning style: {req.preferred_learning_style.value}\n"
            f"Goals / focus areas: {req.goals_or_focus_areas or 'Solid practical and theoretical mastery'}\n"
            f"Research context (live web results):\n{json.dumps(research_context, ensure_ascii=False)}\n"
        )

        data = groq_service.generate_json_response(
            system_prompt, user_prompt, validator=_validate_syllabus_payload
        )

        # 3. Fetch real resources for each module in parallel.
        module_payloads: List[Dict[str, Any]] = data["modules"]
        module_resources = self._fetch_module_resources(topic, module_payloads)

        syllabus_id = uuid.uuid4().hex[:12]
        parsed_modules: List[Module] = []
        all_resources: List[ResourceItem] = list(papers) + list(docs)

        for m_idx, mod_data in enumerate(module_payloads):
            mod_id = f"mod_{m_idx + 1}"
            videos, articles = module_resources[m_idx]
            all_resources.extend(videos + articles)

            subtopics: List[Subtopic] = []
            for s_idx, sub_data in enumerate(mod_data["subtopics"]):
                sub_resources: List[ResourceItem] = []
                if videos:
                    sub_resources.append(videos[s_idx % len(videos)])
                if articles:
                    sub_resources.append(articles[s_idx % len(articles)])
                if papers and m_idx == len(module_payloads) - 1 and s_idx == 0:
                    sub_resources.append(papers[0])

                subtopics.append(Subtopic(
                    id=f"{mod_id}_sub_{s_idx + 1}",
                    title=str(sub_data["title"]).strip(),
                    description=str(sub_data["description"]).strip(),
                    estimated_minutes=_as_minutes(sub_data.get("estimated_minutes")),
                    resources=sub_resources,
                ))

            parsed_modules.append(Module(
                id=mod_id,
                title=str(mod_data["title"]).strip(),
                summary=str(mod_data["summary"]).strip(),
                learning_objectives=_as_str_list(mod_data.get("learning_objectives")),
                order_index=m_idx + 1,
                subtopics=subtopics,
                quiz_id=f"quiz_{mod_id}",
                is_unlocked=(m_idx == 0),
                is_passed=False,
            ))

        syllabus = Syllabus(
            id=syllabus_id,
            topic=topic,
            user_experience_level=req.experience_level,
            primary_learning_style=req.preferred_learning_style,
            industry_standards_summary=str(data["industry_standards_summary"]).strip(),
            prerequisites=_as_str_list(data.get("prerequisites")),
            learning_outcomes=_as_str_list(data.get("learning_outcomes")),
            latest_trends_identified=_as_str_list(data.get("latest_trends"), limit=5),
            modules=parsed_modules,
        )

        # Index in RAG for live chat & quiz grounding.
        rag_service.index_resources(syllabus_id, all_resources)
        rag_service.index_resources(topic, all_resources)

        return syllabus

    @staticmethod
    def _fetch_module_resources(topic: str, modules: List[Dict[str, Any]]):
        """Return a list of (videos, articles) tuples, one per module."""
        def fetch(mod: Dict[str, Any]):
            query = f"{topic} {mod['title']}"
            try:
                videos = youtube_service.search_learning_videos(query, max_results=2)
            except Exception as exc:
                logger.warning(f"Video search failed for '{query}': {exc}")
                videos = []
            try:
                articles = scraper_service.search_articles_and_docs(query, max_results=2)
            except Exception as exc:
                logger.warning(f"Article search failed for '{query}': {exc}")
                articles = []
            return videos, articles

        with ThreadPoolExecutor(max_workers=4) as pool:
            return list(pool.map(fetch, modules))


syllabus_agent = SyllabusArchitectAgent()
