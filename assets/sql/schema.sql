-- ============================================================================
-- DreamSync Local Database Schema (Encrypted SQLite via SQLCipher)
--
-- Stores sensitive data in plaintext locally (the DB itself is encrypted).
-- The is_synced flag tracks offline-first sync state:
--   0 = not yet pushed to Supabase (encrypted)
--   1 = successfully synced
--
-- Supabase stores the same data but encrypted (see supabase_schema.sql).
-- ============================================================================

-- 1. Sleep Record (full detail — stages + hypnogram stored locally only)
CREATE TABLE IF NOT EXISTS sleep_record (
  sleep_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  total_minutes INTEGER NOT NULL DEFAULT 0 CHECK (total_minutes >= 0),
  sleep_score INTEGER NOT NULL DEFAULT 0 CHECK (sleep_score >= 0 AND sleep_score <= 100),

  deep_minutes INTEGER NOT NULL DEFAULT 0 CHECK (deep_minutes >= 0),
  light_minutes INTEGER NOT NULL DEFAULT 0 CHECK (light_minutes >= 0),
  rem_minutes INTEGER NOT NULL DEFAULT 0 CHECK (rem_minutes >= 0),
  awake_minutes INTEGER NOT NULL DEFAULT 0 CHECK (awake_minutes >= 0),
  hypnogram_json TEXT,

  mood_feedback TEXT CHECK (
    mood_feedback IS NULL OR mood_feedback IN ('sad', 'neutral', 'happy')
  ),

  is_synced INTEGER NOT NULL DEFAULT 0 CHECK (is_synced IN (0, 1)),

  UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_sleep_record_user_id
ON sleep_record(user_id);

CREATE INDEX IF NOT EXISTS idx_sleep_record_user_date
ON sleep_record(user_id, date);

-- 2. Daily Activity (exercise, calories, screen time)
CREATE TABLE IF NOT EXISTS daily_activities (
  activity_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  exercise_minutes INTEGER NOT NULL DEFAULT 0 CHECK (exercise_minutes >= 0),
  food_calories INTEGER NOT NULL DEFAULT 0 CHECK (food_calories >= 0),
  screen_time_minutes INTEGER NOT NULL DEFAULT 0 CHECK (screen_time_minutes >= 0),
  burned_calories INTEGER NOT NULL DEFAULT 0 CHECK (burned_calories >= 0),
  is_synced INTEGER NOT NULL DEFAULT 0 CHECK (is_synced IN (0, 1)),
  caffeine_intake_mg REAL DEFAULT 0,
  sugar_intake_g REAL DEFAULT 0,
  alcohol_intake_g REAL DEFAULT 0,
  UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_activities_user_date
ON daily_activities(user_id, date);

-- 3. Sleep Recommendation Cache (ML output — local only, no cloud sync)
CREATE TABLE IF NOT EXISTS sleep_recommendation (
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  recommended_minutes INTEGER NOT NULL,
  expected_score REAL NOT NULL,
  sim_deep_minutes INTEGER NOT NULL,
  sim_rem_minutes INTEGER NOT NULL,
  sim_deep_pct REAL NOT NULL,
  sim_rem_pct REAL NOT NULL,
  explanation TEXT NOT NULL,
  message TEXT,
  generated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, date)
);

-- 4. Sleep Schedule
CREATE TABLE IF NOT EXISTS sleep_schedule (
  schedule_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  target_bed_time TEXT NOT NULL,
  target_wake_time TEXT NOT NULL,
  days TEXT NOT NULL,
  is_alarm_on INTEGER NOT NULL DEFAULT 1 CHECK (is_alarm_on IN (0, 1)),
  is_smart_alarm INTEGER NOT NULL DEFAULT 0 CHECK (is_smart_alarm IN (0, 1)),
  is_smart_notification INTEGER NOT NULL DEFAULT 0 CHECK (is_smart_notification IN (0, 1)),
  item_id INTEGER NOT NULL DEFAULT 1,
  is_snooze_on INTEGER NOT NULL DEFAULT 1 CHECK (is_snooze_on IN (0, 1)),
  snooze_duration_minutes INTEGER NOT NULL DEFAULT 5 CHECK (snooze_duration_minutes >= 1 AND snooze_duration_minutes <= 15),
  is_synced INTEGER NOT NULL DEFAULT 0 CHECK (is_synced IN (0, 1)),
  UNIQUE(user_id, target_bed_time, target_wake_time, days)
);

CREATE INDEX IF NOT EXISTS idx_sleep_schedule_user_id
ON sleep_schedule(user_id);

-- 5. User Achievement Progress Cache
CREATE TABLE IF NOT EXISTS user_achievement (
  user_achievement_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  achievement_id TEXT NOT NULL,
  current_progress REAL NOT NULL DEFAULT 0,
  is_unlocked INTEGER NOT NULL DEFAULT 0 CHECK (is_unlocked IN (0, 1)),
  is_claimed INTEGER NOT NULL DEFAULT 0 CHECK (is_claimed IN (0, 1)),
  date_claimed TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0 CHECK (is_synced IN (0, 1)),
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievement_user_id
ON user_achievement(user_id);

CREATE INDEX IF NOT EXISTS idx_user_achievement_user_achievement
ON user_achievement(user_id, achievement_id);

-- 6. Achievement Definitions Cache
CREATE TABLE IF NOT EXISTS achievement (
  achievement_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  criteria_type TEXT,
  criteria_value REAL,
  category TEXT,
  xp_reward INTEGER NOT NULL DEFAULT 0
);

-- 7. Friends Cache
CREATE TABLE IF NOT EXISTS friend_cache (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  friend_id TEXT NOT NULL,
  friend_name TEXT,
  friend_avatar TEXT,
  email TEXT,
  uid_text TEXT,
  sleep_goal_hours REAL NOT NULL DEFAULT 0,
  streak INTEGER NOT NULL DEFAULT 0,
  UNIQUE(user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_cache_user_id
ON friend_cache(user_id);

-- 8. Profile Cache
CREATE TABLE IF NOT EXISTS profile (
  user_id TEXT PRIMARY KEY,
  avatar_asset_path TEXT,
  username TEXT,
  email TEXT,
  gender TEXT,
  date_birth TEXT,
  weight REAL DEFAULT 0,
  height REAL DEFAULT 0,
  uid_text TEXT,
  current_points INTEGER NOT NULL DEFAULT 0,
  sleep_goal_hours REAL NOT NULL DEFAULT 8.0,
  streak INTEGER NOT NULL DEFAULT 0,
  is_synced INTEGER NOT NULL DEFAULT 0 CHECK (is_synced IN (0, 1))
);