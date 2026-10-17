import logging
import urllib.parse
import xml.etree.ElementTree as ET
from typing import List, Dict, Any, Optional
import requests
from ..models.schemas import ResourceItem, ResourceType

logger = logging.getLogger(__name__)

class WebScraperService:
    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        }

    def search_web_trends(self, topic: str, max_results: int = 5) -> List[Dict[str, str]]:
        """
        Scrapes real-time web search results for the topic focused on latest trends and standards.
        """
        results = []
        query = f"{topic} latest industry trends standards 2025 2026"
        try:
            from duckduckgo_search import DDGS
            with DDGS() as ddgs:
                ddg_results = list(ddgs.text(query, max_results=max_results))
                for item in ddg_results:
                    results.append({
                        "title": item.get("title", ""),
                        "url": item.get("href", ""),
                        "snippet": item.get("body", ""),
                        "source": "Web Search"
                    })
        except Exception as e:
            logger.warning(f"DuckDuckGo search error: {e}")
        return results

    def search_youtube_videos(self, topic: str, max_results: int = 4) -> List[ResourceItem]:
        """
        Finds curated video tutorials, tech talks, and conference breakdowns via YouTube Data API v3.
        """
        try:
            from .youtube_service import youtube_service
            return youtube_service.search_learning_videos(topic, max_results=max_results)
        except Exception as e:
            logger.warning(f"Video search delegation failed: {e}")
            return []

    def search_arxiv_papers(self, topic: str, max_results: int = 3) -> List[ResourceItem]:
        """
        Queries ArXiv's official public API for research papers on the topic.
        """
        papers = []
        try:
            encoded_query = urllib.parse.quote(topic)
            url = f"https://export.arxiv.org/api/query?search_query=all:{encoded_query}&start=0&max_results={max_results}&sortBy=relevance&sortOrder=descending"
            resp = requests.get(url, timeout=8, headers=self.headers)
            if resp.status_code == 200:
                root = ET.fromstring(resp.text)
                ns = {"atom": "http://www.w3.org/2005/Atom"}
                for idx, entry in enumerate(root.findall("atom:entry", ns)):
                    title = entry.find("atom:title", ns)
                    summary = entry.find("atom:summary", ns)
                    paper_id = entry.find("atom:id", ns)
                    published = entry.find("atom:published", ns)
                    authors = [a.find("atom:name", ns).text for a in entry.findall("atom:author", ns) if a.find("atom:name", ns) is not None]
                    author_str = ", ".join(authors[:2]) + (" et al." if len(authors) > 2 else "")

                    title_text = " ".join((title.text or "").split())
                    summary_text = " ".join((summary.text or "").split())
                    paper_url = paper_id.text if paper_id is not None and paper_id.text else f"https://arxiv.org/abs/{idx}"

                    papers.append(ResourceItem(
                        id=f"arxiv_{idx}_{abs(hash(title_text)) % 100000}",
                        title=title_text,
                        type=ResourceType.PAPER,
                        url=paper_url,
                        snippet=summary_text[:280] + ("..." if len(summary_text) > 280 else ""),
                        source_name="ArXiv",
                        author_or_channel=author_str or None,
                        published_date=(published.text[:10] if published is not None and published.text else None),
                        key_takeaways=[]
                    ))
        except Exception as e:
            logger.warning(f"ArXiv API search error: {e}")

        return papers

    def search_articles_and_docs(self, topic: str, max_results: int = 4) -> List[ResourceItem]:
        """
        Finds technical blog articles, RFCs, and documentation.
        """
        articles = []
        try:
            from duckduckgo_search import DDGS
            with DDGS() as ddgs:
                ddg_results = list(ddgs.text(f"{topic} architecture documentation guide", max_results=max_results))
                for idx, item in enumerate(ddg_results):
                    url = item.get("href", "")
                    if not url:
                        continue
                    articles.append(ResourceItem(
                        id=f"art_{idx}_{abs(hash(url)) % 100000}",
                        title=item.get("title") or url,
                        type=ResourceType.ARTICLE,
                        url=url,
                        snippet=item.get("body", ""),
                        source_name=urllib.parse.urlparse(url).netloc.replace("www.", "") or "Web",
                    ))
        except Exception as e:
            logger.warning(f"Article search error: {e}")
        return articles

scraper_service = WebScraperService()
