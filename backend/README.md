# Backend Service

This folder contains server-side APIs and background jobs.

## Suggested stack
- Runtime: Node.js + TypeScript
- API framework: Express
- Validation: Zod
- Database: SQLite (managed in DBeaver)

## Quick Start

1. Copy `backend/.env.example` to `backend/.env` and set `SQLITE_DB_PATH`.
2. If you want SOS SMS delivery, also set `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER` in `backend/.env`.
3. Install dependencies: `npm install`
4. Start dev server: `npm run dev`

Default SQLite path in `.env.example` points to `../database/assets/health_app.db`.

Default API base URL: `http://localhost:8080/api/v1`

## Implemented Endpoints

- `GET /health` database-aware health check
- `POST /profiles` create user mental-health profile
- `GET /profiles/:id` fetch one profile by integer id
- `POST /check-ins` create check-in and AI suggestions
- `GET /check-ins/:profileId` list recent check-ins by integer profile id
- `POST /vitals` ingest watch/phone vitals and auto-create alerts
- `GET /alerts/:profileId` list recent alerts for a user by integer profile id
- `POST /alerts/:alertId/ack` mark alert as acknowledged by integer alert id

## SOS SMS Delivery

The SOS endpoint sends an SMS to the saved emergency contact only when the backend process has the Twilio variables configured:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_FROM_NUMBER`

Without those variables, the backend still records the SOS alert but skips SMS delivery.

## Structure
- `src/api/routes/` HTTP route handlers and versioned endpoints
- `src/core/` app configuration, logging, security middleware
- `src/services/` business logic and use-case orchestration
- `src/workers/` async/background jobs and queue consumers
- `tests/` integration and unit tests

## Next implementation steps
1. Add authentication and profile ownership.
2. Add geospatial search integration for nearby safe locations.
3. Add agent orchestration endpoint for guided crisis conversations.
4. Add CI checks and integration tests.
