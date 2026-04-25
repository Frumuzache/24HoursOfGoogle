from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Sequence
from urllib import error, request


@dataclass(frozen=True)
class OllamaClientConfig:
    base_url: str
    model: str
    timeout_seconds: int = 120


class OllamaClient:
    """Minimal HTTP client for Ollama chat completions."""

    def __init__(self, config: OllamaClientConfig) -> None:
        self._config = config

    def chat(self, system_prompt: str, user_prompt: str) -> str:
        return self.chat_messages(
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ]
        )

    def chat_with_history(
        self,
        system_prompt: str,
        user_prompt: str,
        history: list[dict[str, str]],
    ) -> str:
        """Send message with conversation history for context."""
        messages = [{"role": "system", "content": system_prompt}]
        
        # Add conversation history
        for msg in history:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            messages.append({"role": role, "content": content})
        
        # Add current user message
        messages.append({"role": "user", "content": user_prompt})
        
        return self.chat_messages(messages)

    def chat_messages(self, messages: Sequence[dict[str, str]]) -> str:
        endpoint = f"{self._config.base_url.rstrip('/')}/api/chat"
        payload = {
            "model": self._config.model,
            "stream": False,
            "messages": list(messages),
        }
        body = json.dumps(payload).encode("utf-8")
        http_request = request.Request(
            endpoint,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with request.urlopen(http_request, timeout=self._config.timeout_seconds) as response:
                response_data = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Ollama chat request failed with HTTP {exc.code}: {detail}"
            ) from exc
        except error.URLError as exc:
            raise RuntimeError(
                f"Could not reach Ollama at {self._config.base_url}. Is ollama running?"
            ) from exc

        return self._extract_content(response_data)

    @staticmethod
    def _extract_content(payload: dict[str, Any]) -> str:
        message = payload.get("message")
        if isinstance(message, dict):
            content = message.get("content")
            if isinstance(content, str):
                return content.strip()

        response = payload.get("response")
        if isinstance(response, str):
            return response.strip()

        return ""