-- 1. Sleep Record Table
-- Stores summary data for cloud sync and detailed stage data locally only.
CREATE TABLE IF NOT EXISTS sleep_record (
  id TEXT PRIMARY KEY,
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

-- 2. Daily Activity Table
CREATE TABLE IF NOT EXISTS daily_activity (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  exercise_minutes INTEGER DEFAULT 0,
  food_calories INTEGER DEFAULT 0,
  screen_time_minutes INTEGER DEFAULT 0,
  is_synced INTEGER DEFAULT 0,
  UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_activity_user_date
ON daily_activity(user_id, date);

-- 3. Schedule Table
CREATE TABLE IF NOT EXISTS schedule (
  id TEXT PRIMARY KEY,
  schedule_id INTEGER,
  user_id TEXT NOT NULL,
  target_bed_time TEXT,
  target_wake_time TEXT,
  days TEXT,
  is_alarm_on INTEGER DEFAULT 1,
  is_smart_alarm INTEGER DEFAULT 0,
  is_smart_notification INTEGER DEFAULT 0,
  is_snooze_on INTEGER DEFAULT 1,
  item_id INTEGER,
  created_at TEXT,
  is_synced INTEGER DEFAULT 0
);

-- 4. User Achievements Cache
CREATE TABLE IF NOT EXISTS user_achievement (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  achievement_id TEXT NOT NULL,
  progress REAL DEFAULT 0,
  is_unlocked INTEGER DEFAULT 0,
  is_synced INTEGER DEFAULT 0
);

-- 5. Achievement Definitions Cache
CREATE TABLE IF NOT EXISTS achievement_definition (
  id TEXT PRIMARY KEY,
  title TEXT,
  description TEXT,
  criteria_type TEXT,
  criteria_value REAL,
  category TEXT,
  xp_reward INTEGER DEFAULT 0,
  icon_path TEXT
);

-- 6. Friends Cache
CREATE TABLE IF NOT EXISTS friend_cache (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  friend_id TEXT NOT NULL,
  friend_name TEXT,
  friend_avatar TEXT
);
