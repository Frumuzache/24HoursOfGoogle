from __future__ import annotations

from pathlib import Path
from typing import Mapping

from .config import CONFIG
from .ollama_client import OllamaClient, OllamaClientConfig
from .prompt_manager import PromptManager


class InferenceService:
    """Coordinates prompt construction and local Ollama generation."""

    def __init__(self, project_root: Path) -> None:
        prompts_dir = project_root / "ai" / "prompts"
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
    ) -> str:
        system_prompt = self._prompt_manager.build(
            user_input=user_input,
            template_name=template_name,
            variables=variables,
        )
        return self._client.chat(system_prompt=system_prompt, user_prompt=user_input)
