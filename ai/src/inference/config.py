from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _load_dotenv() -> None:
    candidates = [
        Path(__file__).resolve().parents[3] / ".env",  # repo root (local)
        Path(__file__).resolve().parents[2] / ".env",  # /app/.env (container)
        Path.cwd() / ".env",  # current working directory fallback
    ]

    env_path = next((path for path in candidates if path.exists()), None)
    if env_path is None:
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


_load_dotenv()


@dataclass(frozen=True)
class InferenceConfig:
    """Runtime settings for local model inference via Ollama."""

    ollama_url: str = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434")
    ollama_model: str = os.getenv("OLLAMA_MODEL", "gemma3:4b")
    request_timeout_seconds: int = int(os.getenv("OLLAMA_TIMEOUT_SECONDS", "120"))
    inference_timeout_seconds: int = int(os.getenv("INFERENCE_TIMEOUT_SECONDS", "60"))
    google_places_api_key: str = os.getenv("GOOGLE_PLACES_API_KEY", "")
    places_radius_meters: int = int(os.getenv("PLACES_RADIUS_METERS", "3000"))


CONFIG = InferenceConfig()
