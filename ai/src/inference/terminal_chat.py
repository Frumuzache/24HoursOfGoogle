from __future__ import annotations

import argparse
from pathlib import Path

from .ollama_client import OllamaClient, OllamaClientConfig
from .prompt_manager import PromptManager
from .config import CONFIG


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
    }


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
