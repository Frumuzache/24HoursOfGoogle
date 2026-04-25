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

DROP TRIGGER IF EXISTS trg_user_profiles_updated_at;
CREATE TRIGGER trg_user_profiles_updated_at
AFTER UPDATE ON user_profiles
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE user_profiles SET updated_at = datetime('now') WHERE id = OLD.id;
END;
