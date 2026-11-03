-- ============================================================
-- An Tâm - cơ sở dữ liệu (SQLite)
-- server.py tự chạy file này khi khởi động (an toàn khi chạy lại).
-- Giờ giấc lưu dạng chuỗi ISO theo giờ địa phương: 'YYYY-MM-DDTHH:MM:SS'.
-- ============================================================

-- Mọi tài khoản: admin, người con (child), bố mẹ (elder)
CREATE TABLE IF NOT EXISTS users (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  role        TEXT NOT NULL CHECK(role IN ('admin','child','elder')),
  name        TEXT NOT NULL,              -- với bố mẹ: tên gọi dùng trong giọng nhắc ("Bà Lan")
  email       TEXT UNIQUE,                -- admin / người con đăng nhập bằng email
  pw_hash     TEXT,                       -- pbkdf2-sha256
  phone       TEXT,
  login_code  TEXT UNIQUE,                -- bố mẹ đăng nhập bằng mã 6 số
  birth_year  INTEGER,
  note        TEXT,                       -- ghi chú sức khỏe (bệnh nền, dị ứng...)
  active      INTEGER NOT NULL DEFAULT 1, -- 0 = bị admin khóa
  created_at  TEXT NOT NULL
);

-- Phiên đăng nhập (token gửi trong header Authorization: Bearer ...)
CREATE TABLE IF NOT EXISTS sessions (
  token       TEXT PRIMARY KEY,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL
);

-- Người con nào theo dõi bố/mẹ nào (nhiều anh chị em có thể cùng theo dõi)
CREATE TABLE IF NOT EXISTS family_links (
  child_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  elder_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (child_id, elder_id)
);

-- Đơn thuốc. times = mảng JSON các giờ uống, vd ["07:30","19:00"]
CREATE TABLE IF NOT EXISTS medications (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  elder_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  dosage      TEXT,
  note        TEXT,
  times       TEXT NOT NULL,
  start_date  TEXT,                       -- 'YYYY-MM-DD', NULL = từ lúc tạo
  end_date    TEXT,                       -- 'YYYY-MM-DD', NULL = dùng lâu dài (vd: toa 7 ngày)
  active      INTEGER NOT NULL DEFAULT 1, -- xóa mềm để giữ lịch sử
  created_at  TEXT NOT NULL,
  ended_at    TEXT
);

-- Mỗi lần uống đã được xác nhận. Không có dòng + quá giờ = "quên uống"
CREATE TABLE IF NOT EXISTS dose_logs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  med_id      INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  elder_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date        TEXT NOT NULL,              -- 'YYYY-MM-DD'
  time        TEXT NOT NULL,              -- 'HH:MM' (một trong medications.times)
  status      TEXT NOT NULL CHECK(status IN ('taken','skipped')),
  logged_at   TEXT NOT NULL,
  logged_by   INTEGER REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(med_id, date, time)
);

-- Chỉ số sức khỏe. type: bp (value=tâm thu, value2=tâm trương), hr, sugar, weight, temp, spo2
CREATE TABLE IF NOT EXISTS health_records (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  elder_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  value       REAL NOT NULL,
  value2      REAL,
  note        TEXT,
  recorded_at TEXT NOT NULL,
  recorded_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);

-- Cảnh báo bố mẹ gửi cho con (nút "Tôi thấy không khỏe")
CREATE TABLE IF NOT EXISTS alerts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  elder_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind        TEXT NOT NULL,
  message     TEXT,
  created_at  TEXT NOT NULL,
  resolved    INTEGER NOT NULL DEFAULT 0
);

-- Lịch tập thể dục. days = mảng JSON các thứ trong tuần, 1 = Thứ 2 ... 7 = Chủ nhật
CREATE TABLE IF NOT EXISTS exercises (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  elder_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,             -- vd: "Đi bộ", "Dưỡng sinh"
  time         TEXT NOT NULL,             -- 'HH:MM'
  days         TEXT NOT NULL,
  duration_min INTEGER NOT NULL DEFAULT 30,
  note         TEXT,
  start_date   TEXT,
  end_date     TEXT,
  active       INTEGER NOT NULL DEFAULT 1,
  created_at   TEXT NOT NULL
);

-- Những buổi tập đã hoàn thành
CREATE TABLE IF NOT EXISTS exercise_logs (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  exercise_id  INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  elder_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date         TEXT NOT NULL,
  logged_at    TEXT NOT NULL,
  logged_by    INTEGER REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(exercise_id, date)
);

CREATE INDEX IF NOT EXISTS idx_dose_logs_elder_date ON dose_logs(elder_id, date);
CREATE INDEX IF NOT EXISTS idx_health_elder_time   ON health_records(elder_id, recorded_at);
CREATE INDEX IF NOT EXISTS idx_meds_elder          ON medications(elder_id);
CREATE INDEX IF NOT EXISTS idx_alerts_elder        ON alerts(elder_id, resolved);
CREATE INDEX IF NOT EXISTS idx_exercises_elder       ON exercises(elder_id);
