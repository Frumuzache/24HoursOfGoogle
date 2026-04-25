from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class InferenceConfig:
    """Runtime settings for local model inference via Ollama."""

    ollama_url: str = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434")
    ollama_model: str = os.getenv("OLLAMA_MODEL", "gemma3:4b")
    request_timeout_seconds: int = int(os.getenv("OLLAMA_TIMEOUT_SECONDS", "120"))


CONFIG = InferenceConfig()
