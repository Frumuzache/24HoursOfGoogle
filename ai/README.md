# AI Layer

This folder contains model logic, inference services, and training pipelines.

## Structure
- `src/inference/` model loading, serving adapters, and response formatting
- `src/training/` training jobs, experiment scripts, and evaluation
- `src/features/` feature extraction and preprocessing
- `models/` local model artifacts (gitignored in real projects)
- `prompts/` prompt templates and prompt versioning files
- `notebooks/` exploratory notebooks and experiments

## Local Inference (Implemented)

The project now includes a local Ollama-backed inference service for Gemma 3 4B:

- `src/inference/config.py` runtime config via environment variables
- `src/inference/prompt_manager.py` prompt template loading/building
- `src/inference/ollama_client.py` HTTP client for Ollama chat completions
- `src/inference/service.py` orchestration layer
- `src/inference/api.py` FastAPI app with `/health` and `/infer`
- `src/inference/run_local_server.py` local server runner
- `src/inference/terminal_chat.py` interactive terminal chat runner

## Install

From repository root:

```bash
.venv\Scripts\python.exe -m pip install -r ai\requirements.txt
```

Make sure Ollama is running locally and the model is available:

```bash
ollama pull gemma3:4b
ollama serve
```

## Run locally

```bash
.venv\Scripts\python.exe -m ai.src.inference.run_local_server
```

Server starts at `http://127.0.0.1:8000`.

## Chat in terminal

```bash
.venv\Scripts\python.exe -m ai.src.inference.terminal_chat --show-prompt
```

This starts an interactive conversation in the terminal using the same prompt template and the same Ollama model. The `--show-prompt` flag prints the rendered system prompt so you can confirm the placeholders are being filled.

## Test endpoint

```bash
curl -X POST http://127.0.0.1:8000/infer \
	-H "Content-Type: application/json" \
	-d '{
		"input":"I am feeling overwhelmed.",
		"user_name":"Alex",
		"heart_rate":"112",
		"calming_methods":"slow breathing, cold water",
		"hobbies":"music, gaming",
		"nearby_safe_places":"living room, front porch"
	}'
```

## Configuration

Set these optional environment variables before starting the server:

- `OLLAMA_URL` (default: `http://127.0.0.1:11434`)
- `OLLAMA_MODEL` (default: `gemma3:4b`)
- `OLLAMA_TIMEOUT_SECONDS` (default: `120`)

Example:

```bash
set OLLAMA_MODEL=gemma3:4b
.venv\Scripts\python.exe -m ai.src.inference.run_local_server
```
