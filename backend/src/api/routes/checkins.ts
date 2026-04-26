import { Router } from "express";
import { z } from "zod";
import { db } from "../../core/db";
import { buildSafetySuggestions } from "../../services/recommendations";
import { sendEmergencySms } from "../../services/sms";

export const checkinsRouter = Router();

const createCheckinSchema = z.object({
  profileId: z.coerce.number().int().positive(),
  moodScore: z.number().int().min(1).max(10),
  anxietyLevel: z.number().int().min(1).max(10),
  panicAttack: z.boolean().default(false),
  heartRate: z.number().int().min(0).max(260).optional(),
  hasTakenMedication: z.boolean().default(false),
  notes: z.string().max(4000).optional(),
  locationLabel: z.string().max(200).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

const createSosSchema = z.object({
  profileId: z.coerce.number().int().positive(),
  heartRate: z.number().int().min(0).max(260).optional(),
  locationLabel: z.string().max(200).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  note: z.string().max(1000).optional(),
});

checkinsRouter.post("/check-ins", async (req, res) => {
  const payloadResult = createCheckinSchema.safeParse(req.body);

  if (!payloadResult.success) {
    return res.status(400).json({ error: "Invalid check-in payload", details: payloadResult.error.flatten() });
  }

  const payload = payloadResult.data;

  const profileRow = db
    .prepare("SELECT id FROM user_profiles WHERE id = ?")
    .get(payload.profileId) as { id: number } | undefined;

  if (!profileRow) {
    return res.status(404).json({ error: "Profile not found" });
  }

  const suggestions = buildSafetySuggestions({
    intensity: payload.anxietyLevel,
    hasTakenMedication: payload.hasTakenMedication,
  });

  const insertResult = db.prepare(
    `INSERT INTO check_ins (
      profile_id, mood_score, anxiety_level, panic_attack, heart_rate,
      has_taken_medication, notes, location_label, latitude, longitude,
      ai_priority, ai_actions
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    payload.profileId,
    payload.moodScore,
    payload.anxietyLevel,
    payload.panicAttack ? 1 : 0,
    payload.heartRate ?? null,
    payload.hasTakenMedication ? 1 : 0,
    payload.notes ?? null,
    payload.locationLabel ?? null,
    payload.latitude ?? null,
    payload.longitude ?? null,
    suggestions.priority,
    JSON.stringify(suggestions.actions),
  );

  const checkinId = Number(insertResult.lastInsertRowid);

  const row = db
    .prepare(
      `SELECT id, profile_id, mood_score, anxiety_level, panic_attack, heart_rate,
              has_taken_medication, notes, location_label, latitude, longitude,
              ai_priority, ai_actions, created_at
       FROM check_ins
      WHERE id = ?`,
    )
    .get(checkinId) as Record<string, unknown> | undefined;

  if (!row) {
    return res.status(500).json({ error: "Failed to create check-in" });
  }

  return res.status(201).json({
    ...row,
    panic_attack: Boolean(row.panic_attack),
    has_taken_medication: Boolean(row.has_taken_medication),
    ai_actions: JSON.parse(String(row.ai_actions ?? "[]")),
  });
});

checkinsRouter.get("/check-ins/:profileId", async (req, res) => {
  const profileIdResult = z.coerce.number().int().positive().safeParse(req.params.profileId);

  if (!profileIdResult.success) {
    return res.status(400).json({ error: "Profile id must be a positive integer" });
  }

  const profileId = profileIdResult.data;
  const limit = Math.min(Number(req.query.limit ?? 20), 100);

  const rows = db
    .prepare(
      `SELECT id, profile_id, mood_score, anxiety_level, panic_attack, heart_rate,
              has_taken_medication, notes, location_label, latitude, longitude,
              ai_priority, ai_actions, created_at
       FROM check_ins
       WHERE profile_id = ?
       ORDER BY created_at DESC
       LIMIT ?`,
    )
    .all(profileId, Number.isNaN(limit) ? 20 : limit) as Array<Record<string, unknown>>;

  const items = rows.map((row) => ({
    ...row,
    panic_attack: Boolean(row.panic_attack),
    has_taken_medication: Boolean(row.has_taken_medication),
    ai_actions: JSON.parse(String(row.ai_actions ?? "[]")),
  }));

  return res.status(200).json({ items });
});

checkinsRouter.post("/sos", async (req, res) => {
  const payloadResult = createSosSchema.safeParse(req.body);
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

  const suggestions = buildSafetySuggestions({
    intensity: 10,
    hasTakenMedication: false,
  });

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
    console.log("[SOS] Sending SMS to:", profile.emergency_contact_phone);
    try {
      smsNotification = await sendEmergencySms({
        phone: profile.emergency_contact_phone,
        message: `${profile.display_name ?? "A user"} triggered an SOS. ${alertMessage}`,
      });
      console.log("[SOS] SMS result:", smsNotification);
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
