# Google Hackkathon

This repository now follows a modular structure to support separate implementations for frontend, backend, AI, and database concerns.

## Architecture

- `frontend/` client applications and shared UI contracts
- `backend/` API services and background processing
- `ai/` model inference, training pipelines, and prompt assets
- `database/` schema, migrations, and seed data

The current Flutter app still exists at repository root (`lib/`, `android/`, `ios/`, etc.) so your current development flow is not broken.

## Suggested Project Layout

<<<<<<< HEAD
For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

-laaaa
=======
```text
.
|-- frontend/
|   |-- mobile_flutter/
|   |-- web_app/
|   |-- admin_dashboard/
|   `-- shared/
|-- backend/
|   |-- src/
|   |   |-- api/routes/
|   |   |-- core/
|   |   |-- services/
|   |   `-- workers/
|   `-- tests/
|-- ai/
|   |-- src/
|   |   |-- inference/
|   |   |-- training/
|   |   `-- features/
|   |-- models/
|   |-- prompts/
|   `-- notebooks/
`-- database/
	|-- schema/
	|-- migrations/
	|-- seeds/
	`-- scripts/
```

## Implementation Notes

1. Continue building your existing Flutter app at root until you are ready to migrate it into `frontend/mobile_flutter/`.
2. Pick a backend runtime and initialize dependencies in `backend/`.
3. Define API contracts between `backend/` and `ai/`.
4. Add versioned migrations and seed data in `database/` before integrating persistent storage.

## Root Flutter App

You can still run the existing app from repository root:

```bash
flutter pub get
flutter run
```
>>>>>>> origin/main
