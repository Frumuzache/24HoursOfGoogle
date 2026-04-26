import cors from "cors";
import express from "express";
import { env } from "./core/config";
import { initializeDatabase, verifyDatabaseConnection } from "./core/db";
import { healthRouter } from "./api/routes/health";
import { profilesRouter } from "./api/routes/profiles";
import { checkinsRouter } from "./api/routes/checkins";
import { vitalsRouter } from "./api/routes/vitals";
import authRoutes from "./api/routes/auth";
import { db } from "./core/db";
import { buildSafetySuggestions } from "./services/recommendations";
import { sendEmergencySms } from "./services/sms";
import { z } from "zod";

const app = express();

app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.get("/", (_req, res) => {
  res.status(200).json({
    service: "mental-safety-backend",
    version: "0.1.0",
    docs: "/api/v1/health",
  });
});

app.use("/api/v1", healthRouter);
app.use("/api/v1", profilesRouter);
app.use("/api/v1", checkinsRouter);
app.use("/api/v1", vitalsRouter);
app.use("/api/v1/auth", authRoutes);

const sosRequestSchema = z.object({
  profileId: z.coerce.number().int().positive(),
  heartRate: z.number().int().min(0).max(260).optional(),
  locationLabel: z.string().max(200).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  note: z.string().max(1000).optional(),
});

app.post("/api/v1/sos", async (req, res) => {
  const payloadResult = sosRequestSchema.safeParse(req.body);
  if (!payloadResult.success) {
    return res.status(400).json({ error: "Invalid SOS payload", details: payloadResult.error.flatten() });
  }

  const payload = payloadResult.data;

  const profile = db
    .prepare(
      `SELECT id, display_name, emergency_contact_name, emergency_contact_phone
       FROM user_profiles
       WHERE id = ?`,
    )
    .get(payload.profileId) as
    | {
        id: number;
        display_name: string | null;
        emergency_contact_name: string | null;
        emergency_contact_phone: string | null;
      }
    | undefined;

  if (!profile) {
    return res.status(404).json({ error: "Profile not found" });
  }

  const suggestions = buildSafetySuggestions({ intensity: 10, hasTakenMedication: false });

  const checkinResult = db
    .prepare(
      `INSERT INTO check_ins (
        profile_id, mood_score, anxiety_level, panic_attack, heart_rate,
        has_taken_medication, notes, location_label, latitude, longitude,
        ai_priority, ai_actions
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .run(
      payload.profileId,
      2,
      10,
      1,
      payload.heartRate ?? null,
      0,
      payload.note ?? "SOS triggered from app",
      payload.locationLabel ?? null,
      payload.latitude ?? null,
      payload.longitude ?? null,
      suggestions.priority,
      JSON.stringify(suggestions.actions),
    );

  const checkinId = Number(checkinResult.lastInsertRowid);

  const alertMessage = profile.emergency_contact_name
    ? `SOS triggered. Please contact ${profile.emergency_contact_name} and move to a safer location now.`
    : "SOS triggered. No emergency contact configured. Move to a safer location and call local emergency support now.";

  const alertResult = db
    .prepare(
      `INSERT INTO alerts (
        profile_id, vital_id, alert_type, severity, message, acknowledged
      ) VALUES (?, NULL, 'check_in_prompt', 'high', ?, 0)`,
    )
    .run(payload.profileId, alertMessage);

  const alertId = Number(alertResult.lastInsertRowid);

  const alertRow = db
    .prepare(
      `SELECT id, profile_id, vital_id, alert_type, severity, message, acknowledged, created_at
       FROM alerts
       WHERE id = ?`,
    )
    .get(alertId) as Record<string, unknown>;

  let smsNotification:
    | {
        status: "sent" | "skipped" | "unavailable" | "failed";
        provider: "twilio" | "none";
        error?: string;
      }
    | undefined;

  if (profile.emergency_contact_phone) {
    try {
      smsNotification = await sendEmergencySms({
        phone: profile.emergency_contact_phone,
        message: `${profile.display_name ?? "A user"} triggered an SOS. ${alertMessage}`,
      });
    } catch (error) {
      smsNotification = {
        status: "failed",
        provider: "twilio",
        error: error instanceof Error ? error.message : "Unknown SMS error",
      };
    }
  } else {
    smsNotification = {
      status: "skipped",
      provider: "none",
    };
  }

  return res.status(201).json({
    sos: {
      profile_id: payload.profileId,
      check_in_id: checkinId,
      alert: {
        ...alertRow,
        acknowledged: Boolean(alertRow.acknowledged),
      },
      emergency_contact: {
        name: profile.emergency_contact_name,
        phone: profile.emergency_contact_phone,
      },
      notification: smsNotification,
      ai_actions: suggestions.actions,
    },
  });
});

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error("Unhandled API error", err);
  res.status(500).json({ error: "Internal server error" });
});

async function start(): Promise<void> {
  initializeDatabase();
  await verifyDatabaseConnection();

  app.listen(env.PORT, "0.0.0.0", () => {
    console.log(`Backend listening on port ${env.PORT}`);
  });
}

start().catch((error) => {
  console.error("Failed to start backend", error);
  process.exit(1);
});
