import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";
import { env } from "./config";

const backendRoot = path.resolve(__dirname, "../..");
const dbFilePath = path.isAbsolute(env.SQLITE_DB_PATH)
  ? env.SQLITE_DB_PATH
  : path.resolve(backendRoot, env.SQLITE_DB_PATH);

fs.mkdirSync(path.dirname(dbFilePath), { recursive: true });

export const db = new Database(dbFilePath);
db.pragma("foreign_keys = ON");

function tableExists(tableName: string): boolean {
  const row = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?")
    .get(tableName) as { name: string } | undefined;

  return Boolean(row);
}

function ensureUsersSchema(): void {
  if (!tableExists("users")) {
    return;
  }

  const columns = db.prepare("PRAGMA table_info(users)").all() as Array<{ name: string }>;
  const hasUsername = columns.some((column) => column.name === "username");

  if (!hasUsername) {
    db.exec("ALTER TABLE users ADD COLUMN username TEXT;");
  }
}

function isLegacyTextIdSchema(): boolean {
  if (!tableExists("user_profiles")) {
    return false;
  }

  const columns = db.prepare("PRAGMA table_info(user_profiles)").all() as Array<{
    name: string;
    type: string;
  }>;
  const idColumn = columns.find((column) => column.name === "id");

  return idColumn?.type.toUpperCase() === "TEXT";
}

function createIntegerSchema(): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL,
      password TEXT NOT NULL,
      username TEXT,
      created_at TEXT DEFAULT (datetime('now')) NOT NULL
    );

    CREATE TABLE IF NOT EXISTS user_profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      display_name TEXT NOT NULL,
      age INTEGER CHECK (age > 0 AND age <= 120),
      disorders TEXT NOT NULL DEFAULT '[]',
      calming_strategies TEXT NOT NULL DEFAULT '[]',
      favorite_foods TEXT NOT NULL DEFAULT '[]',
      hobbies TEXT NOT NULL DEFAULT '[]',
      medications TEXT NOT NULL DEFAULT '[]',
      emergency_contact_name TEXT,
      emergency_contact_phone TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS check_ins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      mood_score INTEGER NOT NULL CHECK (mood_score BETWEEN 1 AND 10),
      anxiety_level INTEGER NOT NULL CHECK (anxiety_level BETWEEN 1 AND 10),
      panic_attack INTEGER NOT NULL DEFAULT 0,
      heart_rate INTEGER CHECK (heart_rate IS NULL OR (heart_rate >= 0 AND heart_rate <= 260)),
      has_taken_medication INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      location_label TEXT,
      latitude REAL,
      longitude REAL,
      ai_priority TEXT NOT NULL CHECK (ai_priority IN ('low', 'medium', 'high')),
      ai_actions TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS device_vitals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      source TEXT NOT NULL CHECK (source IN ('watch', 'phone', 'manual')),
      heart_rate INTEGER NOT NULL CHECK (heart_rate >= 0 AND heart_rate <= 260),
      hrv INTEGER,
      steps INTEGER,
      stress_level INTEGER CHECK (stress_level IS NULL OR (stress_level BETWEEN 0 AND 10)),
      recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      profile_id INTEGER NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
      vital_id INTEGER REFERENCES device_vitals(id) ON DELETE SET NULL,
      alert_type TEXT NOT NULL CHECK (alert_type IN ('high_heart_rate', 'check_in_prompt')),
      severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high')),
      message TEXT NOT NULL,
      acknowledged INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_check_ins_profile_created_at
      ON check_ins(profile_id, created_at DESC);

    CREATE INDEX IF NOT EXISTS idx_device_vitals_profile_recorded_at
      ON device_vitals(profile_id, recorded_at DESC);

    CREATE INDEX IF NOT EXISTS idx_alerts_profile_created_at
      ON alerts(profile_id, created_at DESC);

    CREATE TRIGGER IF NOT EXISTS trg_user_profiles_updated_at
    AFTER UPDATE ON user_profiles
    FOR EACH ROW
    WHEN NEW.updated_at = OLD.updated_at
    BEGIN
      UPDATE user_profiles SET updated_at = datetime('now') WHERE id = OLD.id;
    END;
  `);
}

function migrateLegacyTextIdSchema(): void {
  const migrate = db.transaction(() => {
    const hasCheckIns = tableExists("check_ins");
    const hasDeviceVitals = tableExists("device_vitals");
    const hasAlerts = tableExists("alerts");

    db.exec("ALTER TABLE user_profiles RENAME TO user_profiles_old;");

    if (hasCheckIns) {
      db.exec("ALTER TABLE check_ins RENAME TO check_ins_old;");
    }

    if (hasDeviceVitals) {
      db.exec("ALTER TABLE device_vitals RENAME TO device_vitals_old;");
    }

    if (hasAlerts) {
      db.exec("ALTER TABLE alerts RENAME TO alerts_old;");
    }

    createIntegerSchema();

    const profileIdMap = new Map<string, number>();
    const profiles = db.prepare("SELECT * FROM user_profiles_old ORDER BY rowid ASC").all() as Array<Record<string, unknown>>;
    const insertProfile = db.prepare(
      `INSERT INTO user_profiles (
        display_name, age, disorders, calming_strategies, favorite_foods, hobbies,
        medications, emergency_contact_name, emergency_contact_phone, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    );

    for (const row of profiles) {
      const result = insertProfile.run(
        row.display_name,
        row.age ?? null,
        row.disorders ?? "[]",
        row.calming_strategies ?? "[]",
        row.favorite_foods ?? "[]",
        row.hobbies ?? "[]",
        row.medications ?? "[]",
        row.emergency_contact_name ?? null,
        row.emergency_contact_phone ?? null,
        row.created_at ?? null,
        row.updated_at ?? null,
      );

      profileIdMap.set(String(row.id), Number(result.lastInsertRowid));
    }

    if (hasCheckIns) {
      const checkIns = db.prepare("SELECT * FROM check_ins_old ORDER BY rowid ASC").all() as Array<Record<string, unknown>>;
      const insertCheckIn = db.prepare(
        `INSERT INTO check_ins (
          profile_id, mood_score, anxiety_level, panic_attack, heart_rate,
          has_taken_medication, notes, location_label, latitude, longitude,
          ai_priority, ai_actions, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      );

      for (const row of checkIns) {
        const mappedProfileId = profileIdMap.get(String(row.profile_id));
        if (!mappedProfileId) {
          continue;
        }

        insertCheckIn.run(
          mappedProfileId,
          row.mood_score,
          row.anxiety_level,
          row.panic_attack ?? 0,
          row.heart_rate ?? null,
          row.has_taken_medication ?? 0,
          row.notes ?? null,
          row.location_label ?? null,
          row.latitude ?? null,
          row.longitude ?? null,
          row.ai_priority,
          row.ai_actions ?? "[]",
          row.created_at ?? null,
        );
      }
    }

    const vitalIdMap = new Map<string, number>();
    if (hasDeviceVitals) {
      const vitals = db.prepare("SELECT * FROM device_vitals_old ORDER BY rowid ASC").all() as Array<Record<string, unknown>>;
      const insertVital = db.prepare(
        `INSERT INTO device_vitals (
          profile_id, source, heart_rate, hrv, steps, stress_level, recorded_at, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      );

      for (const row of vitals) {
        const mappedProfileId = profileIdMap.get(String(row.profile_id));
        if (!mappedProfileId) {
          continue;
        }

        const result = insertVital.run(
          mappedProfileId,
          row.source,
          row.heart_rate,
          row.hrv ?? null,
          row.steps ?? null,
          row.stress_level ?? null,
          row.recorded_at ?? null,
          row.created_at ?? null,
        );

        vitalIdMap.set(String(row.id), Number(result.lastInsertRowid));
      }
    }

    if (hasAlerts) {
      const alerts = db.prepare("SELECT * FROM alerts_old ORDER BY rowid ASC").all() as Array<Record<string, unknown>>;
      const insertAlert = db.prepare(
        `INSERT INTO alerts (
          profile_id, vital_id, alert_type, severity, message, acknowledged, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)`
      );

      for (const row of alerts) {
        const mappedProfileId = profileIdMap.get(String(row.profile_id));
        if (!mappedProfileId) {
          continue;
        }

        const mappedVitalId = row.vital_id == null ? null : (vitalIdMap.get(String(row.vital_id)) ?? null);

        insertAlert.run(
          mappedProfileId,
          mappedVitalId,
          row.alert_type,
          row.severity,
          row.message,
          row.acknowledged ?? 0,
          row.created_at ?? null,
        );
      }
    }

    db.exec("DROP TABLE IF EXISTS alerts_old;");
    db.exec("DROP TABLE IF EXISTS device_vitals_old;");
    db.exec("DROP TABLE IF EXISTS check_ins_old;");
    db.exec("DROP TABLE IF EXISTS user_profiles_old;");
  });

  migrate();
}

export function initializeDatabase(): void {
  ensureUsersSchema();

  if (isLegacyTextIdSchema()) {
    migrateLegacyTextIdSchema();
    return;
  }

  createIntegerSchema();
}

export async function verifyDatabaseConnection(): Promise<void> {
  db.prepare("SELECT 1").get();
}
