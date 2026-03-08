-- 1. Sleep Table
CREATE TABLE IF NOT EXISTS sleep_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id INTEGER,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  total_minutes INTEGER,
  sleep_score INTEGER,
  created_at TEXT,
  is_synced INTEGER DEFAULT 0,
  UNIQUE(user_id, date)
);

-- 2. Daily Activity Table
CREATE TABLE IF NOT EXISTS daily_activity (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  steps INTEGER,
  calories_burned REAL,
  is_synced INTEGER DEFAULT 0
);

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

-- 5. Friends Cache
CREATE TABLE IF NOT EXISTS friend_cache (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  friend_id TEXT NOT NULL,
  friend_name TEXT,
  friend_avatar TEXT
);