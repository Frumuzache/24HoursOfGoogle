import { Router } from "express";
import { z } from "zod";
import { db } from "../../core/db";
import { buildSafetySuggestions } from "../../services/recommendations";

export const checkinsRouter = Router();

const createCheckinSchema = z.object({
  profileId: z.string().min(1),
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

checkinsRouter.post("/check-ins", async (req, res) => {
  const payloadResult = createCheckinSchema.safeParse(req.body);

  if (!payloadResult.success) {
    return res.status(400).json({ error: "Invalid check-in payload", details: payloadResult.error.flatten() });
  }

  const payload = payloadResult.data;

  const profileRow = db
    .prepare("SELECT id FROM user_profiles WHERE id = ?")
    .get(payload.profileId) as { id: string } | undefined;

  if (!profileRow) {
    return res.status(404).json({ error: "Profile not found" });
  }

  const suggestions = buildSafetySuggestions({
    intensity: payload.anxietyLevel,
    hasTakenMedication: payload.hasTakenMedication,
  });

  // Generate UUID-like ID in TypeScript
  const generateId = () => {
    return [
      Math.random().toString(16).slice(2, 10),
      Math.random().toString(16).slice(2, 6),
      Math.random().toString(16).slice(2, 6),
      Math.random().toString(16).slice(2, 6),
      Math.random().toString(16).slice(2, 14),
    ].join('-');
  };

  const checkinId = generateId();

  const insertResult = db.prepare(
    `INSERT INTO check_ins (
      id, profile_id, mood_score, anxiety_level, panic_attack, heart_rate,
      has_taken_medication, notes, location_label, latitude, longitude,
      ai_priority, ai_actions
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    checkinId,
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
