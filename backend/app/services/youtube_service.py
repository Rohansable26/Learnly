"""
youtube_service.py
------------------
Searches YouTube for learning-relevant videos using the official
YouTube Data API v3. Falls back gracefully to DuckDuckGo video
search when no API key is configured.

Setup
-----
1. Go to https://console.cloud.google.com/
2. Create/select a project → Enable "YouTube Data API v3"
3. APIs & Services → Credentials → Create API Key
4. Add to your .env:  YOUTUBE_API_KEY=AIza...
"""

import html
import logging
import os
import urllib.parse
from typing import List

import requests

from ..core.config import settings
from ..models.schemas import ResourceItem, ResourceType

logger = logging.getLogger(__name__)

_YT_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
_YT_VIDEOS_URL = "https://www.googleapis.com/youtube/v3/videos"


class YouTubeService:
    """
    Wraps the YouTube Data API v3 to find high-quality learning videos.

    Priority:
    1. YouTube Data API v3  (requires YOUTUBE_API_KEY)
    2. DuckDuckGo video search (no key needed)
    """

    @property
    def api_key(self) -> str:
        return settings.YOUTUBE_API_KEY or os.getenv("YOUTUBE_API_KEY", "")

    def __init__(self) -> None:
        if self.api_key:
            logger.info("YouTubeService: YouTube Data API v3 key detected ✓")
        else:
            logger.warning(
                "YouTubeService: No YOUTUBE_API_KEY — using DuckDuckGo fallback."
            )

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def search_learning_videos(
        self,
        query: str,
        max_results: int = 4,
        language_code: str = "en",
    ) -> List[ResourceItem]:
        """Return up to *max_results* YouTube videos for *query*."""
        max_results = max(1, min(max_results, 10))

        if self.api_key:
            videos = self._search_via_yt_api(query, max_results, language_code)
            if videos:
                return videos

        return self._search_via_duckduckgo(query, max_results)

    # ------------------------------------------------------------------
    # YouTube Data API v3
    # ------------------------------------------------------------------

    def _search_via_yt_api(
        self, query: str, max_results: int, language_code: str
    ) -> List[ResourceItem]:
        try:
            params = {
                "key": self.api_key,
                "q": f"{query} tutorial",
                "part": "snippet",
                "type": "video",
                "maxResults": max_results,
                "relevanceLanguage": language_code,
                "videoDuration": "medium",   # 4–20 min sweet spot
                "videoEmbeddable": "true",
                "safeSearch": "strict",
                "order": "relevance",
            }
            resp = requests.get(_YT_SEARCH_URL, params=params, timeout=8)

            if resp.status_code == 403:
                logger.error(
                    f"YouTube API 403 — quota exceeded or invalid key: {resp.text[:200]}"
                )
                return []

            resp.raise_for_status()
            items = resp.json().get("items", [])

            # If no items found with medium duration filter, retry without duration constraint
            if not items:
                params.pop("videoDuration", None)
                resp = requests.get(_YT_SEARCH_URL, params=params, timeout=8)
                if resp.status_code == 200:
                    items = resp.json().get("items", [])

            if not items:
                return []

            # Batch-fetch view/like counts
            video_ids = [
                i["id"]["videoId"] for i in items if i.get("id", {}).get("videoId")
            ]
            stats_map = self._fetch_video_stats(video_ids)

            results: List[ResourceItem] = []
            for idx, item in enumerate(items):
                video_id = item.get("id", {}).get("videoId", "")
                sn = item.get("snippet", {})
                title = html.unescape(sn.get("title", f"{query} Tutorial"))
                desc = html.unescape(sn.get("description", ""))
                channel = html.unescape(sn.get("channelTitle", "YouTube Creator"))
                published = sn.get("publishedAt", "")[:10]

                stats = stats_map.get(video_id, {})
                view_count = stats.get("viewCount", "")
                like_count = stats.get("likeCount", "")

                meta_parts = []
                if view_count:
                    meta_parts.append(f"👁 {int(view_count):,} views")
                if like_count:
                    meta_parts.append(f"👍 {int(like_count):,} likes")
                meta = "  ·  ".join(meta_parts)

                rich_snippet = (
                    f"{desc[:200]}{'...' if len(desc) > 200 else ''}"
                    + (f"  |  {meta}" if meta else "")
                ).strip() or f"Comprehensive {query} tutorial."

                results.append(
                    ResourceItem(
                        id=f"yt_api_{idx}_{video_id}",
                        title=title,
                        type=ResourceType.VIDEO,
                        url=f"https://www.youtube.com/watch?v={video_id}",
                        snippet=rich_snippet,
                        source_name="YouTube",
                        author_or_channel=channel,
                        published_date=published,
                        key_takeaways=[],
                    )
                )

            logger.info(
                f"YouTubeService: {len(results)} videos via API for '{query}'"
            )
            return results

        except requests.RequestException as exc:
            logger.warning(f"YouTubeService API request failed: {exc}")
            return []
        except Exception as exc:
            logger.error(f"YouTubeService unexpected error: {exc}")
            return []

    def _fetch_video_stats(self, video_ids: List[str]) -> dict:
        if not video_ids or not self.api_key:
            return {}
        try:
            resp = requests.get(
                _YT_VIDEOS_URL,
                params={
                    "key": self.api_key,
                    "id": ",".join(video_ids),
                    "part": "statistics",
                },
                timeout=6,
            )
            resp.raise_for_status()
            return {
                item["id"]: item.get("statistics", {})
                for item in resp.json().get("items", [])
            }
        except Exception as exc:
            logger.debug(f"YouTubeService: stats fetch skipped — {exc}")
            return {}

    # ------------------------------------------------------------------
    # DuckDuckGo fallback (no key required)
    # ------------------------------------------------------------------

    def _search_via_duckduckgo(self, query: str, max_results: int) -> List[ResourceItem]:
        results: List[ResourceItem] = []
        try:
            from duckduckgo_search import DDGS

            with DDGS() as ddgs:
                ddg_items = list(ddgs.videos(f"{query} tutorial", max_results=max_results))

            for idx, v in enumerate(ddg_items):
                url = v.get("content", "") or v.get("url", "")
                if not url:
                    continue
                results.append(
                    ResourceItem(
                        id=f"yt_ddg_{idx}_{abs(hash(url)) % 100000}",
                        title=v.get("title") or url,
                        type=ResourceType.VIDEO,
                        url=url,
                        snippet=v.get("description", ""),
                        source_name="YouTube",
                        author_or_channel=v.get("uploader"),
                        published_date=v.get("published"),
                        key_takeaways=[],
                    )
                )
            logger.info(f"YouTubeService: {len(results)} videos via DuckDuckGo for '{query}'")
        except Exception as exc:
            logger.warning(f"YouTubeService DuckDuckGo fallback failed: {exc}")
        return results


youtube_service = YouTubeService()
