from __future__ import annotations

from pathlib import Path
from typing import Mapping
import re

from .config import CONFIG
from .ollama_client import OllamaClient, OllamaClientConfig
from .prompt_manager import PromptManager


def _is_location_intent(text: str) -> bool:
    lowered = text.lower()
    patterns = (
        r"\btake me\b",
        r"\bgo to\b",
        r"\bgo there\b",
        r"\bdirections?\b",
        r"\bwhere is\b",
        r"\bfind (me )?(a|the)?\s*(park|library|cafe|garden)\b",
        r"\bnearest\b",
        r"\bclosest\b",
        r"\bpark\b",
    )
    return any(re.search(pattern, lowered) for pattern in patterns)


def _parse_nearby_safe_place(raw_value: str) -> tuple[str, str, str, str] | None:
    if not raw_value or "|" not in raw_value:
        return None

    parts = [part.strip() for part in raw_value.split("|", 3)]
    if len(parts) < 4:
        return None

    name, address, distance, link = parts
    if not name or not link:
        return None

    return name, address, distance, link


def _build_location_reply(place: tuple[str, str, str, str]) -> str:
    name, address, distance, link = place
    details = f"Closest option is {name}"
    if distance:
        details += f", about {distance} away"
    if address:
        details += f", at {address}"
    return f"{details}. Directions: {link}"


class InferenceService:
    def __init__(self, project_root: Path) -> None:
        prompts_dir = project_root / "ai" / "prompts"
        if not prompts_dir.exists():
            prompts_dir = Path(__file__).resolve().parents[2] / "prompts"
        self._prompt_manager = PromptManager(prompts_dir=prompts_dir)
        self._client = OllamaClient(
            OllamaClientConfig(
                base_url=CONFIG.ollama_url,
                model=CONFIG.ollama_model,
                timeout_seconds=CONFIG.request_timeout_seconds,
            )
        )

    def run(
        self,
        user_input: str,
        template_name: str = "default_prompt.txt",
        variables: Mapping[str, str] | None = None,
        conversation_history: list[dict[str, str]] | None = None,
    ) -> str:
        if _is_location_intent(user_input):
            nearby_value = (variables or {}).get("NEARBY_SAFE_PLACES", "")
            parsed_place = _parse_nearby_safe_place(nearby_value)
            if parsed_place is not None:
                return _build_location_reply(parsed_place)

        system_prompt = self._prompt_manager.build(
            user_input=user_input,
            template_name=template_name,
            variables=variables,
        )
        
        if conversation_history:
            return self._client.chat_with_history(
                system_prompt=system_prompt,
                user_prompt=user_input,
                history=conversation_history,
            )
        else:
            return self._client.chat(system_prompt=system_prompt, user_prompt=user_input)