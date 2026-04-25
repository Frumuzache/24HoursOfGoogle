import { Router } from "express";
import { z } from "zod";
import { db } from "../../core/db";

export const vitalsRouter = Router();

const createVitalSchema = z.object({
  profileId: z.coerce.number().int().positive(),
  source: z.enum(["watch", "phone", "manual"]).default("manual"),
  heartRate: z.number().int().min(0).max(260),
  hrv: z.number().int().min(0).max(1000).optional(),
  steps: z.number().int().min(0).max(200000).optional(),
  stressLevel: z.number().int().min(0).max(10).optional(),
  recordedAt: z.string().datetime().optional(),
});

function buildAlertForVital(input: { heartRate: number; stressLevel?: number }):
  | { alertType: "high_heart_rate"; severity: "medium" | "high"; message: string }
  | null {
  if (input.heartRate >= 130) {
    return {
      alertType: "high_heart_rate",
      severity: "high",
      message:
        "Your heart rate is elevated. Please pause, breathe slowly, and confirm if you are safe. If symptoms are severe, contact emergency support.",
    };
  }

  if (input.heartRate >= 110 && (input.stressLevel ?? 0) >= 8) {
    return {
      alertType: "high_heart_rate",
      severity: "medium",
      message:
        "We detected elevated stress with a higher heart rate. Try a grounding exercise and move to a calm location if possible.",
    };
  }

  return null;
}

vitalsRouter.post("/vitals", async (req, res) => {
  const payloadResult = createVitalSchema.safeParse(req.body);

  if (!payloadResult.success) {
    return res.status(400).json({ error: "Invalid vital payload", details: payloadResult.error.flatten() });
  }

  const payload = payloadResult.data;

  const profileRow = db
    .prepare("SELECT id FROM user_profiles WHERE id = ?")
    .get(payload.profileId) as { id: number } | undefined;

  if (!profileRow) {
    return res.status(404).json({ error: "Profile not found" });
  }

  const insertVitalResult = db.prepare(
    `INSERT INTO device_vitals (
      profile_id, source, heart_rate, hrv, steps, stress_level, recorded_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(
    payload.profileId,
    payload.source,
    payload.heartRate,
    payload.hrv ?? null,
    payload.steps ?? null,
    payload.stressLevel ?? null,
    payload.recordedAt ?? new Date().toISOString(),
  );

  const vitalId = Number(insertVitalResult.lastInsertRowid);

  const alertCandidate = buildAlertForVital({
    heartRate: payload.heartRate,
    stressLevel: payload.stressLevel,
  });

  let createdAlert: Record<string, unknown> | null = null;

  if (alertCandidate) {
    const insertAlertResult = db.prepare(
      `INSERT INTO alerts (
        profile_id, vital_id, alert_type, severity, message, acknowledged
      ) VALUES (?, ?, ?, ?, ?, 0)`
    ).run(
      payload.profileId,
      vitalId,
      alertCandidate.alertType,
      alertCandidate.severity,
      alertCandidate.message,
    );

    const alertId = Number(insertAlertResult.lastInsertRowid);

    createdAlert = db
      .prepare(
        `SELECT id, profile_id, vital_id, alert_type, severity, message, acknowledged, created_at
         FROM alerts
         WHERE id = ?`,
      )
      .get(alertId) as Record<string, unknown> | null;
  }

  const vitalRow = db
    .prepare(
      `SELECT id, profile_id, source, heart_rate, hrv, steps, stress_level, recorded_at, created_at
       FROM device_vitals
       WHERE id = ?`,
    )
    .get(vitalId) as Record<string, unknown>;

  return res.status(201).json({
    vital: vitalRow,
    alert: createdAlert
      ? {
          ...createdAlert,
          acknowledged: Boolean(createdAlert.acknowledged),
        }
      : null,
  });
});

vitalsRouter.get("/alerts/:profileId", async (req, res) => {
  const profileIdResult = z.coerce.number().int().positive().safeParse(req.params.profileId);

  if (!profileIdResult.success) {
    return res.status(400).json({ error: "Profile id must be a positive integer" });
  }

  const profileId = profileIdResult.data;
  const limit = Math.min(Number(req.query.limit ?? 30), 100);

  const rows = db
    .prepare(
      `SELECT id, profile_id, vital_id, alert_type, severity, message, acknowledged, created_at
       FROM alerts
       WHERE profile_id = ?
       ORDER BY created_at DESC
       LIMIT ?`,
    )
    .all(profileId, Number.isNaN(limit) ? 30 : limit) as Array<Record<string, unknown>>;

  const items = rows.map((row) => ({
    ...row,
    acknowledged: Boolean(row.acknowledged),
  }));

  return res.status(200).json({ items });
});

vitalsRouter.post("/alerts/:alertId/ack", async (req, res) => {
  const alertIdResult = z.coerce.number().int().positive().safeParse(req.params.alertId);

  if (!alertIdResult.success) {
    return res.status(400).json({ error: "Alert id must be a positive integer" });
  }

  const alertId = alertIdResult.data;

  const result = db
    .prepare("UPDATE alerts SET acknowledged = 1 WHERE id = ?")
    .run(alertId);

  if (result.changes === 0) {
    return res.status(404).json({ error: "Alert not found" });
  }

  const row = db
    .prepare(
      `SELECT id, profile_id, vital_id, alert_type, severity, message, acknowledged, created_at
       FROM alerts
       WHERE id = ?`,
    )
    .get(alertId) as Record<string, unknown>;

  return res.status(200).json({
    ...row,
    acknowledged: Boolean(row.acknowledged),
  });
});
