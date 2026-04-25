# Backend Service

This folder contains server-side APIs and background jobs.

## Suggested stack
- API framework: FastAPI, Express, or Dart Frog
- Auth: JWT/OAuth2 provider
- Deployment: Docker + cloud runtime

## Structure
- `src/api/routes/` HTTP route handlers and versioned endpoints
- `src/core/` app configuration, logging, security middleware
- `src/services/` business logic and use-case orchestration
- `src/workers/` async/background jobs and queue consumers
- `tests/` integration and unit tests

## Next implementation steps
1. Choose backend runtime (Python, Node.js, or Dart).
2. Add dependency manager files (`requirements.txt` / `package.json` / `pubspec.yaml`).
3. Implement health and auth endpoints first.
4. Add CI checks for lint, test, and build.
