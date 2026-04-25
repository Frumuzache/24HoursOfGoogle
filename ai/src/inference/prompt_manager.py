from __future__ import annotations

import re
from pathlib import Path
from typing import Mapping


_PLACEHOLDER_PATTERN = re.compile(r"{{\s*([A-Z0-9_]+)\s*}}")


class PromptManager:
    """Loads prompt templates from ai/prompts directory."""

    def __init__(self, prompts_dir: Path) -> None:
        self._prompts_dir = prompts_dir

    def load(self, template_name: str = "default_prompt.txt") -> str:
        path = self._prompts_dir / template_name
        if not path.exists():
            raise FileNotFoundError(
                f"Prompt template '{template_name}' not found in '{self._prompts_dir}'."
            )
        return path.read_text(encoding="utf-8")

    def build(
        self,
        user_input: str,
        template_name: str = "default_prompt.txt",
        variables: Mapping[str, str] | None = None,
    ) -> str:
        template = self.load(template_name)
        values: dict[str, str] = {"USER_INPUT": user_input.strip()}
        if variables:
            values.update({key.upper(): value for key, value in variables.items()})

        def replace(match: re.Match[str]) -> str:
            return values.get(match.group(1), "")

        return _PLACEHOLDER_PATTERN.sub(replace, template)
