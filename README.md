# Safety Net 🛟

A mental health safety companion built for the **24 Hours of Google** hackathon.

Safety Net helps users manage anxiety and panic episodes with an AI-powered chat companion, real-time vitals monitoring, guided check-ins, and an SOS system that alerts a trusted emergency contact by SMS.

## ✨ Features

- **AI Companion** – empathetic chat powered by a locally-hosted LLM (Ollama / Gemma 3) that knows your conditions, calming strategies, and hobbies
- **Voice interaction** – talk to the assistant using speech input, replies are spoken back with TTS
- **Heart rate monitoring** – pulse-based vitals tracking from the phone camera
- **Check-ins** – log mood, anxiety level, panic attacks, medication, and location notes
- **SOS emergency mode** – one tap sends an SMS (via Twilio or Infobip) with the user's location and heart rate to their emergency contact
- **Nearby safe places** – finds calming spots (parks, libraries, cafés) around you using the Google Places API
- **Smart recommendations** – personalized safety suggestions based on check-in data
- **Wearable-friendly UI** – watch interface for quick access
- **Persistent sessions** – stay logged in until you manually sign out

## 🏗️ Architecture

```
.
├── frontend/
│   ├── mobile_flutter/     # Flutter mobile app (main client)
│   ├── web_app/            # (planned)
│   └── shared/
├── backend/                # Express + TypeScript API (mental-safety-backend)
├── ai/                     # FastAPI inference service (Ollama + Google Places)
├── database/               # SQLite schema, migrations, seeds
├── lib/                    # Legacy root Flutter app (still runnable)
└── docker-compose.yml
```

| Layer | Tech |
|-------|------|
| Mobile app | Flutter (Dart) |
| Backend API | Node.js, Express, TypeScript, Zod |
| Database | SQLite (`better-sqlite3`) |
| AI service | Python, FastAPI, Ollama (`gemma3:4b`), Google Places API |
| Notifications | Twilio / Infobip SMS |

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Node.js](https://nodejs.org/) ≥ 18
- [Python](https://www.python.org/) ≥ 3.10
- [Ollama](https://ollama.com/) running locally
- A Google Places API key

### 1. Database

The SQLite database lives at `database/assets/health_app.db`. To set it up from scratch (e.g. in DBeaver):

1. Open `database/assets/health_app.db`
2. Run `database/migrations/20260425_001_baseline.sql`
3. Optionally run `database/seeds/001_demo_seed.sql` for demo data

### 2. Backend API

```bash
cd backend
cp .env.example .env        # fill in Twilio/Infobip credentials
npm install
npm run dev                 # http://localhost:8080
```

Or with Docker:

```bash
docker compose up api       # http://localhost:8080
```

Main endpoints (prefix `/api/v1`): `auth`, `profiles`, `checkins`, `vitals`, `health`, plus `POST /api/v1/sos`.

### 3. AI Service

```bash
ollama pull gemma3:4b       # once

cd ai/src/inference
pip install fastapi uvicorn httpx
python run_local_server.py  # http://localhost:8000
```

Environment variables (optional, loaded from `.env` at repo root):

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Ollama server URL |
| `OLLAMA_MODEL` | `gemma3:4b` | Model to use |
| `GOOGLE_PLACES_API_KEY` | – | Google Places key |
| `PLACES_RADIUS_METERS` | `3000` | Search radius for safe places |

### 4. Mobile App

```bash
cd frontend/mobile_flutter
cp .env.example .env        # add your Google Places API key
flutter pub get
flutter run
```

## 📱 App Flow

1. **Login / Register** → create your profile
2. **Onboarding** → add conditions, calming methods, hobbies, emergency contact
3. **Dashboard** → vitals, check-ins, AI chat, and SOS button

## 🧪 Development

```bash
# Typecheck backend
cd backend && npm run typecheck

# Analyze Flutter code (root project)
flutter analyze

# Run tests
flutter test
```

## 👥 Team

Built in 24 hours at the Google Hackathon by [Frumuzache](https://github.com/Frumuzache) & co.

---

> ⚠️ This is a hackathon prototype, not a medical device. In a real emergency, always call your local emergency number.
