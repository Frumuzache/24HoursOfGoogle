import { Router } from "express";
import { z } from "zod";
import { db } from "../../core/db";

export const profilesRouter = Router();

const createProfileSchema = z.object({
  displayName: z.string().min(1),
  age: z.number().int().positive().max(120).optional(),
  disorders: z.array(z.string().min(1)).default([]),
  calmingStrategies: z.array(z.string().min(1)).default([]),
  favoriteFoods: z.array(z.string().min(1)).default([]),
  hobbies: z.array(z.string().min(1)).default([]),
  medications: z.array(z.string().min(1)).default([]),
  emergencyContactName: z.string().min(1).optional(),
  emergencyContactPhone: z.string().min(3).optional(),
});

profilesRouter.post("/profiles", async (req, res) => {
  const payloadResult = createProfileSchema.safeParse(req.body);

  if (!payloadResult.success) {
    return res.status(400).json({ error: "Invalid profile payload", details: payloadResult.error.flatten() });
  }

  const payload = payloadResult.data;

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

  const profileId = generateId();

  const insertResult = db.prepare(
    `INSERT INTO user_profiles (
      id, display_name, age, disorders, calming_strategies, favorite_foods, hobbies,
      medications, emergency_contact_name, emergency_contact_phone
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    profileId,
    payload.displayName,
    payload.age ?? null,
    JSON.stringify(payload.disorders),
    JSON.stringify(payload.calmingStrategies),
    JSON.stringify(payload.favoriteFoods),
    JSON.stringify(payload.hobbies),
    JSON.stringify(payload.medications),
    payload.emergencyContactName ?? null,
    payload.emergencyContactPhone ?? null,
  );

  const row = db
    .prepare(
      `SELECT id, display_name, age, disorders, calming_strategies, favorite_foods,
              hobbies, medications, emergency_contact_name, emergency_contact_phone,
              created_at, updated_at
       FROM user_profiles
       WHERE id = ?`,
    )
    .get(profileId) as Record<string, unknown> | undefined;

  if (!row) {
    return res.status(500).json({ error: "Failed to create profile" });
  }

  return res.status(201).json({
    ...row,
    disorders: JSON.parse(String(row.disorders ?? "[]")),
    calming_strategies: JSON.parse(String(row.calming_strategies ?? "[]")),
    favorite_foods: JSON.parse(String(row.favorite_foods ?? "[]")),
    hobbies: JSON.parse(String(row.hobbies ?? "[]")),
    medications: JSON.parse(String(row.medications ?? "[]")),
  });
});

profilesRouter.get("/profiles/:id", async (req, res) => {
  const idResult = z.string().min(1).safeParse(req.params.id);

  if (!idResult.success) {
    return res.status(400).json({ error: "Profile id must be a valid string" });
  }

  const id = idResult.data;

  const row = db
    .prepare(
      `SELECT id, display_name, age, disorders, calming_strategies, favorite_foods,
              hobbies, medications, emergency_contact_name, emergency_contact_phone,
              created_at, updated_at
       FROM user_profiles
       WHERE id = ?`,
    )
    .get(id) as Record<string, unknown> | undefined;

  if (!row) {
    return res.status(404).json({ error: "Profile not found" });
  }

  return res.status(200).json({
    ...row,
    disorders: JSON.parse(String(row.disorders ?? "[]")),
    calming_strategies: JSON.parse(String(row.calming_strategies ?? "[]")),
    favorite_foods: JSON.parse(String(row.favorite_foods ?? "[]")),
    hobbies: JSON.parse(String(row.hobbies ?? "[]")),
    medications: JSON.parse(String(row.medications ?? "[]")),
  });
});
