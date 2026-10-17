"""
groq_service.py
---------------
AI inference via Groq Cloud — ultra-fast LLM serving backed by
custom LPU hardware.

Model choices (set GROQ_MODEL in .env):
  - openai/gpt-oss-120b       (default — high-capability 120B reasoning MoE)
  - llama-3.3-70b-versatile   (balanced 70B model)
  - llama-3.1-8b-instant      (ultra-fast instant model)

Setup
-----
1. Sign up at https://console.groq.com/
2. Create an API key (free tier available)
3. Add to your .env:  GROQ_API_KEY=gsk_...

Robustness
----------
Every call is retried with exponential backoff. JSON calls are additionally
validated (optionally with a caller-supplied validator) and, on a bad
response, the model is re-asked with the parse/validation error so it can
correct itself. When everything fails an ``AIServiceError`` is raised —
this service never returns placeholder content.
"""

import json
import logging
import re
import time
from typing import Any, Callable, Dict, List, Optional

from ..core.config import settings

logger = logging.getLogger(__name__)


class AIServiceError(RuntimeError):
    """Raised when the AI provider cannot produce a usable response."""


# A validator returns None when the payload is acceptable, or an error message.
JsonValidator = Callable[[Any], Optional[str]]


class GroqService:
    """Wraps the Groq Cloud API with retries and structured-output validation."""

    MAX_ATTEMPTS = 3
    BASE_BACKOFF_SECONDS = 1.0

    def __init__(self) -> None:
        self.api_key: str = settings.GROQ_API_KEY
        self.model: str = settings.GROQ_MODEL
        self.client = None

        if self.api_key:
            try:
                from groq import Groq  # pip install groq
                self.client = Groq(api_key=self.api_key, timeout=60.0, max_retries=0)
                logger.info(f"GroqService: client initialised ✓  model={self.model}")
            except ImportError:
                logger.error("GroqService: 'groq' package not installed. Run: pip install groq")
            except Exception as exc:
                logger.error(f"GroqService: init error — {exc}")
        else:
            logger.warning("GroqService: No GROQ_API_KEY — AI features are unavailable.")

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    @property
    def is_ready(self) -> bool:
        return self.client is not None

    def generate_text_response(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.6,
        max_tokens: int = 4096,
    ) -> str:
        """Generate free-form Markdown. Raises AIServiceError on failure."""
        return self.generate_chat_response(
            system_prompt,
            [{"role": "user", "content": user_prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
        )

    def generate_chat_response(
        self,
        system_prompt: str,
        messages: List[Dict[str, str]],
        temperature: float = 0.6,
        max_tokens: int = 4096,
    ) -> str:
        """Generate a reply for a multi-turn conversation. Raises AIServiceError on failure."""
        full_messages = [{"role": "system", "content": system_prompt}, *messages]
        text = self._complete_with_retry(full_messages, temperature, max_tokens)
        if not text.strip():
            raise AIServiceError("The AI model returned an empty response.")
        return text.strip()

    def generate_json_response(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.3,
        max_tokens: int = 6000,
        validator: Optional[JsonValidator] = None,
    ) -> Dict[str, Any]:
        """
        Generate a structured JSON object.

        The response is parsed and passed through ``validator``. If either step
        fails, the model is re-prompted with the error so it can repair its
        output. Raises AIServiceError when no valid object can be obtained.
        """
        json_system = (
            system_prompt
            + "\n\nIMPORTANT: Respond ONLY with a single valid JSON object — "
            "no markdown fences, no prose, no trailing text."
        )
        messages: List[Dict[str, str]] = [
            {"role": "system", "content": json_system},
            {"role": "user", "content": user_prompt},
        ]

        last_error = "unknown error"
        for attempt in range(1, self.MAX_ATTEMPTS + 1):
            raw = self._complete_with_retry(
                messages, temperature, max_tokens, json_mode=True
            )
            data = self._parse_json(raw)
            if data is None:
                last_error = "Response was not valid JSON."
            else:
                problem = validator(data) if validator else None
                if problem is None:
                    return data
                last_error = problem

            logger.warning(f"GroqService: JSON attempt {attempt} rejected — {last_error}")
            # Ask the model to repair its own output.
            messages = messages[:2] + [
                {"role": "assistant", "content": raw[:6000]},
                {
                    "role": "user",
                    "content": (
                        f"Your previous response was invalid: {last_error} "
                        "Return the corrected, complete JSON object only."
                    ),
                },
            ]

        raise AIServiceError(f"AI returned malformed structured data ({last_error}).")

    def get_model_info(self) -> Dict[str, Any]:
        """Return current model configuration info."""
        return {
            "provider": "Groq Cloud",
            "model": self.model,
            "api_key_set": bool(self.api_key),
            "client_ready": self.client is not None,
            "docs": "https://console.groq.com/docs/models",
        }

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _complete_with_retry(
        self,
        messages: List[Dict[str, str]],
        temperature: float,
        max_tokens: int,
        json_mode: bool = False,
    ) -> str:
        if not self.client:
            raise AIServiceError(
                "AI provider is not configured. Set GROQ_API_KEY in backend/.env."
            )

        use_json_format = json_mode
        last_exc: Optional[Exception] = None
        for attempt in range(1, self.MAX_ATTEMPTS + 1):
            try:
                kwargs: Dict[str, Any] = dict(
                    model=self.model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                )
                if use_json_format:
                    kwargs["response_format"] = {"type": "json_object"}
                completion = self.client.chat.completions.create(**kwargs)
                return completion.choices[0].message.content or ""
            except Exception as exc:
                last_exc = exc
                msg = str(exc).lower()
                # Some models reject response_format; retry without it.
                if use_json_format and ("response_format" in msg or "json_validate" in msg):
                    use_json_format = False
                    continue
                # Don't retry auth / bad-request errors — they won't succeed.
                if any(code in msg for code in ("401", "403", "invalid api key", "invalid_api_key")):
                    break
                logger.warning(f"GroqService: attempt {attempt} failed — {exc}")
                if attempt < self.MAX_ATTEMPTS:
                    time.sleep(self.BASE_BACKOFF_SECONDS * (2 ** (attempt - 1)))

        raise AIServiceError(f"AI provider request failed: {last_exc}")

    @staticmethod
    def _parse_json(raw: str) -> Optional[Any]:
        """Parse JSON, tolerating markdown fences or leading/trailing prose."""
        if not raw:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
        match = re.search(r"```(?:json)?\s*([\s\S]*?)```", raw)
        if match:
            try:
                return json.loads(match.group(1).strip())
            except json.JSONDecodeError:
                pass
        start, end = raw.find("{"), raw.rfind("}")
        if start != -1 and end > start:
            try:
                return json.loads(raw[start:end + 1])
            except json.JSONDecodeError:
                pass
        return None


groq_service = GroqService()
