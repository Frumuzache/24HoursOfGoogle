from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from .service import InferenceService

app = FastAPI(title="Google Hackkathon Local AI", version="0.1.0")
service = InferenceService(project_root=Path(__file__).resolve().parents[3])


class InferenceRequest(BaseModel):
    input: str = Field(..., min_length=1, description="User input text")
    template_name: str = Field(
        default="default_prompt.txt",
        description="Prompt file name from ai/prompts",
    )
    user_name: str = ""
    user_conditions: str = ""
    heart_rate: str = ""
    calming_methods: str = ""
    hobbies: str = ""
    nearby_safe_places: str = ""
    conversation_history: list[dict[str, str]] = Field(
        default_factory=list,
        description="Previous conversation messages for context",
    )


class InferenceResponse(BaseModel):
    output: str


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/infer", response_model=InferenceResponse)
def infer(payload: InferenceRequest) -> InferenceResponse:
    try:
        variables = {
            "USER_NAME": payload.user_name,
            "USER_CONDITIONS": payload.user_conditions,
            "HEART_RATE": payload.heart_rate,
            "CALMING_METHODS": payload.calming_methods,
            "HOBBIES": payload.hobbies,
            "NEARBY_SAFE_PLACES": payload.nearby_safe_places,
        }
        output = service.run(
            user_input=payload.input,
            template_name=payload.template_name,
            variables=variables,
            conversation_history=payload.conversation_history,
        )
        return InferenceResponse(output=output)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Inference failed: {exc}") from exc