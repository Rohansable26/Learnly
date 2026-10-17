import math
import re
import threading
from typing import List, Dict, Any, Tuple
from ..models.schemas import ResourceItem


def _tokenize(text: str) -> List[str]:
    return re.findall(r"\w+", text.lower())


class KnowledgeChunk:
    def __init__(self, chunk_id: str, content: str, metadata: Dict[str, Any]):
        self.chunk_id = chunk_id
        self.content = content
        self.metadata = metadata
        self.words = set(_tokenize(content))


class LightweightRAGService:
    """
    In-memory keyword retrieval over scraped resources and generated lessons.
    Knowledge is keyed by topic (or syllabus id) and accumulates over time.
    """

    MAX_CHUNKS_PER_KEY = 400
    LESSON_CHUNK_CHARS = 1200

    def __init__(self):
        self.knowledge_base: Dict[str, List[KnowledgeChunk]] = {}
        self._lock = threading.Lock()

    @staticmethod
    def _key(topic_id: str) -> str:
        return topic_id.strip().lower()

    def _add_chunks(self, topic_id: str, chunks: List[KnowledgeChunk]) -> None:
        key = self._key(topic_id)
        with self._lock:
            existing = self.knowledge_base.setdefault(key, [])
            seen = {c.chunk_id for c in existing}
            existing.extend(c for c in chunks if c.chunk_id not in seen)
            if len(existing) > self.MAX_CHUNKS_PER_KEY:
                del existing[: len(existing) - self.MAX_CHUNKS_PER_KEY]

    @staticmethod
    def _resource_chunk(res: ResourceItem) -> KnowledgeChunk:
        return KnowledgeChunk(
            chunk_id=f"res::{res.url or res.id}",
            content=f"{res.title}. {res.snippet} {' '.join(res.key_takeaways)}",
            metadata={
                "title": res.title,
                "url": res.url,
                "type": res.type.value if hasattr(res.type, "value") else str(res.type),
                "source": res.source_name,
            },
        )

    def index_resources(self, topic_id: str, resources: List[ResourceItem]):
        """Indexes scraped resources for grounding."""
        self._add_chunks(topic_id, [self._resource_chunk(r) for r in resources])

    def add_lesson(self, topic_id: str, subtopic_title: str, markdown: str, resources: List[ResourceItem]):
        """Indexes a generated lesson (split into sections) plus its resources."""
        sections = [s.strip() for s in re.split(r"\n(?=#{1,3} )", markdown) if s.strip()]
        chunks: List[KnowledgeChunk] = []
        for idx, section in enumerate(sections):
            for part_idx in range(0, len(section), self.LESSON_CHUNK_CHARS):
                part = section[part_idx: part_idx + self.LESSON_CHUNK_CHARS]
                chunks.append(KnowledgeChunk(
                    chunk_id=f"lesson::{subtopic_title}::{idx}::{part_idx}",
                    content=part,
                    metadata={"title": f"Lesson: {subtopic_title}", "source": "Learnly lesson"},
                ))
        chunks.extend(self._resource_chunk(r) for r in resources)
        self._add_chunks(topic_id, chunks)

    def search_relevant_chunks(self, topic_id: str, query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """BM25-style keyword scoring of query tokens against indexed chunks."""
        with self._lock:
            chunks = list(self.knowledge_base.get(self._key(topic_id), []))
        if not chunks:
            return []

        query_tokens = set(_tokenize(query))
        if not query_tokens:
            return []

        n = len(chunks)
        df = {t: sum(1 for c in chunks if t in c.words) for t in query_tokens}
        scored: List[Tuple[float, KnowledgeChunk]] = []
        for chunk in chunks:
            score = 0.0
            for t in query_tokens:
                if t in chunk.words:
                    idf = math.log(1 + (n - df[t] + 0.5) / (df[t] + 0.5))
                    score += idf
            score /= math.sqrt(len(chunk.words) + 1)
            if score > 0:
                scored.append((score, chunk))

        scored.sort(key=lambda x: x[0], reverse=True)
        return [
            {"content": c.content, "metadata": c.metadata, "score": round(s, 4)}
            for s, c in scored[:top_k]
        ]


rag_service = LightweightRAGService()
