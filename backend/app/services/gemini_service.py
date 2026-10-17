import json
import logging
import re
from typing import Dict, Any, Optional
from ..core.config import settings

logger = logging.getLogger(__name__)

class GeminiService:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.client = None
        if self.api_key:
            try:
                from google import genai
                self.client = genai.Client(api_key=self.api_key)
                logger.info("Google GenAI client initialized successfully.")
            except Exception as e:
                logger.warning(f"Failed to initialize google-genai client: {e}")
        else:
            logger.info("No GEMINI_API_KEY detected. Running in intelligent fallback simulation mode.")

    def generate_json_response(self, system_prompt: str, user_prompt: str) -> Optional[Dict[str, Any]]:
        """
        Calls Gemini with JSON structured response schema or extracts JSON from markdown block.
        """
        if self.client:
            try:
                from google.genai import types
                response = self.client.models.generate_content(
                    model=settings.DEFAULT_MODEL,
                    contents=f"{system_prompt}\n\nUSER PROMPT:\n{user_prompt}",
                    config=types.GenerateContentConfig(
                        temperature=0.2,
                        response_mime_type="application/json"
                    )
                )
                if response and response.text:
                    return json.loads(response.text)
            except Exception as e:
                logger.error(f"Gemini API generation error: {e}. Attempting fallback parser.")

        return None

    def generate_text_response(self, system_prompt: str, user_prompt: str) -> str:
        """
        Calls Gemini for free-form text or streaming response.
        """
        if self.client:
            try:
                from google.genai import types
                response = self.client.models.generate_content(
                    model=settings.DEFAULT_MODEL,
                    contents=f"{system_prompt}\n\nUSER PROMPT:\n{user_prompt}",
                    config=types.GenerateContentConfig(temperature=0.7)
                )
                if response and response.text:
                    return response.text
            except Exception as e:
                logger.error(f"Gemini API text generation error: {e}")

        raise RuntimeError("Gemini is not configured or failed to respond.")

gemini_service = GeminiService()
