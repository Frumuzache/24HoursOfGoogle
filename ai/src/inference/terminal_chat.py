from __future__ import annotations

import argparse
from pathlib import Path
import re

from .ollama_client import OllamaClient, OllamaClientConfig
from .prompt_manager import PromptManager
from .config import CONFIG
from .places_client import GooglePlacesClient


def _ask(prompt_text: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{prompt_text}{suffix}: ").strip()
    return value or default


def _collect_variables() -> dict[str, str]:
    print("\nSetează contextul inițial pentru prompt. Poți lăsa gol câmpurile pe care nu vrei să le completezi.")
    return {
        "USER_NAME": _ask("Name"),
        "USER_CONDITIONS": _ask("Known conditions"),
        "HEART_RATE": _ask("Current heart rate"),
        "CALMING_METHODS": _ask("Favorite calming methods"),
        "HOBBIES": _ask("Favorite hobbies/interests"),
        "NEARBY_SAFE_PLACES": _ask("Safe locations nearby"),
        "USER_LATITUDE": _ask("Current latitude (optional)"),
        "USER_LONGITUDE": _ask("Current longitude (optional)"),
        "PREFERRED_CALMING_TYPE": _ask("Preferred calming place type", "park"),
    }


def _is_nearest_calm_request(user_text: str) -> bool:
    text = user_text.lower()
    trigger_words = ("nearest", "closest", "nearby", "aproape", "closest place")
    action_words = (
        "take me",
        "go to",
        "bring me",
        "find me",
        "vreau",
        "du-ma",
        "du ma",
        "merg",
    )
    calm_words = ("calm", "calming", "safe place", "linistit", "liniștit", "park", "library", "cafe", "garden")

    has_calm_target = any(word in text for word in calm_words)
    has_distance_intent = any(word in text for word in trigger_words)
    has_go_intent = any(word in text for word in action_words)
    return has_calm_target and (has_distance_intent or has_go_intent)


def _extract_place_type(user_text: str, fallback: str) -> str:
    known_types = ("park", "library", "cafe", "garden", "church", "bookstore", "museum")
    text = user_text.lower()
    for place_type in known_types:
        if place_type in text:
            return place_type

    match = re.search(r"type\s*[:=]\s*([a-zA-Z_ ]+)", user_text)
    if match:
        return match.group(1).strip().lower()
    return fallback.lower()


def _parse_nearest_command(user_text: str) -> str | None:
    text = user_text.strip()
    if not text.lower().startswith("/nearest"):
        return None

    parts = text.split(maxsplit=1)
    if len(parts) == 1:
        return "park"
    return parts[1].strip().lower() or "park"


def _build_nearest_place_reply(
    place_type: str,
    place_name: str,
    address: str,
    distance_meters: int,
    latitude: float,
    longitude: float,
    maps_url: str,
    maps_fallback_url: str,
) -> str:
    return (
        f"Am găsit cel mai apropiat loc de tip '{place_type}': {place_name}. "
        f"Adresă: {address}. Distanță aproximativă: {distance_meters} m. "
        f"Coordonate: {latitude:.6f}, {longitude:.6f}. "
        f"Google Maps: {maps_url}. "
        f"Fallback: {maps_fallback_url}"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Interactive terminal chat with local Ollama model.")
    parser.add_argument(
        "--template",
        default="default_prompt.txt",
        help="Prompt template file from ai/prompts",
    )
    parser.add_argument(
        "--show-prompt",
        action="store_true",
        help="Print the rendered system prompt before chatting",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    project_root = Path(__file__).resolve().parents[3]
    prompts_dir = project_root / "ai" / "prompts"

    prompt_manager = PromptManager(prompts_dir=prompts_dir)
    client = OllamaClient(
        OllamaClientConfig(
            base_url=CONFIG.ollama_url,
            model=CONFIG.ollama_model,
            timeout_seconds=CONFIG.request_timeout_seconds,
        )
    )

    variables = _collect_variables()
    places_client = GooglePlacesClient(
        api_key=CONFIG.google_places_api_key,
        radius_meters=CONFIG.places_radius_meters,
        timeout_seconds=min(CONFIG.request_timeout_seconds, 20),
    )
    system_prompt = prompt_manager.build(
        user_input="",
        template_name=args.template,
        variables=variables,
    )

    if args.show_prompt:
        print("\n--- SYSTEM PROMPT START ---\n")
        print(system_prompt)
        print("\n--- SYSTEM PROMPT END ---\n")

    print("\nConversație pornită. Scrie /quit ca să ieși.\n")
    history: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]

    while True:
        try:
            user_text = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nIeșire.")
            break

        if not user_text:
            continue
        if user_text.lower() in {"/quit", "/exit"}:
            print("Ieșire.")
            break

        command_place_type = _parse_nearest_command(user_text)
        if command_place_type is not None or _is_nearest_calm_request(user_text):
            lat_text = variables.get("USER_LATITUDE", "").strip()
            lng_text = variables.get("USER_LONGITUDE", "").strip()
            preferred_type = command_place_type or _extract_place_type(
                user_text,
                fallback=variables.get("PREFERRED_CALMING_TYPE", "park"),
            )

            if not lat_text or not lng_text:
                print("Assistant: Ca să găsesc cel mai apropiat loc calm, am nevoie de latitudine și longitudine. Repornește chat-ul și completează coordonatele.\n")
                continue

            try:
                latitude = float(lat_text)
                longitude = float(lng_text)
            except ValueError:
                print("Assistant: Coordonatele nu sunt valide. Folosește format numeric, de exemplu 44.4268 și 26.1025.\n")
                continue

            try:
                nearest_place = places_client.find_nearest(
                    latitude=latitude,
                    longitude=longitude,
                    place_type=preferred_type,
                )
            except Exception as exc:
                print(f"Assistant: Nu am putut interoga Google Places API: {exc}\n")
                continue

            if nearest_place is None:
                print(
                    "Assistant: Nu am găsit un loc potrivit în apropiere pentru tipul cerut. "
                    "Încearcă alt tip, de exemplu park sau library.\n"
                )
                continue

            guaranteed_reply = _build_nearest_place_reply(
                place_type=preferred_type,
                place_name=nearest_place.name,
                address=nearest_place.address,
                distance_meters=nearest_place.distance_meters,
                latitude=nearest_place.latitude,
                longitude=nearest_place.longitude,
                maps_url=nearest_place.maps_url,
                maps_fallback_url=nearest_place.maps_fallback_url,
            )
            print(f"Assistant: {guaranteed_reply}\n")
            history.append({"role": "assistant", "content": guaranteed_reply})
            continue

        history.append({"role": "user", "content": user_text})
        try:
            answer = client.chat_messages(history)
        except Exception as exc:
            print(f"\n[error] {exc}\n")
            continue

        print(f"Assistant: {answer}\n")
        history.append({"role": "assistant", "content": answer})


if __name__ == "__main__":
    main()
