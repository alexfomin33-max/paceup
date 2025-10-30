-- ────────────────────────────────────────────────────────────────────────────
--  DRIFT DATABASE SCHEMA VERSION 1
--
--  Начальная схема для offline-first кэширования
--  Создана: 2025-10-29
--  Автор: AI Assistant
-- ────────────────────────────────────────────────────────────────────────────

-- ────────────────────────── Таблица: cached_activities ──────────────────────────

CREATE TABLE cached_activities (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  
  -- Основные поля
  activity_id INTEGER NOT NULL,
  lenta_id INTEGER NOT NULL UNIQUE,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  
  -- Даты
  date_start DATETIME,
  date_end DATETIME,
  
  -- Пользовательские данные
  user_name TEXT NOT NULL,
  user_avatar TEXT NOT NULL,
  user_group INTEGER NOT NULL,
  
  -- Счётчики
  likes INTEGER NOT NULL DEFAULT 0,
  comments INTEGER NOT NULL DEFAULT 0,
  is_like INTEGER NOT NULL DEFAULT 0, -- BOOLEAN as INTEGER (0 or 1)
  
  -- Пост данные
  post_date_text TEXT NOT NULL DEFAULT '',
  post_media_url TEXT NOT NULL DEFAULT '',
  post_content TEXT NOT NULL DEFAULT '',
  
  -- Сложные типы (JSON)
  equipments TEXT NOT NULL DEFAULT '[]',
  stats TEXT,
  points TEXT NOT NULL DEFAULT '[]',
  media_images TEXT NOT NULL DEFAULT '[]',
  media_videos TEXT NOT NULL DEFAULT '[]',
  
  -- Метаданные кэша
  cached_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cache_owner INTEGER NOT NULL
);

-- Индексы для быстрого поиска
CREATE INDEX idx_activities_lenta_id ON cached_activities(lenta_id);
CREATE INDEX idx_activities_user_cached ON cached_activities(cache_owner, cached_at DESC);

-- ────────────────────────── Таблица: cached_profiles ──────────────────────────

CREATE TABLE cached_profiles (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  
  user_id INTEGER NOT NULL UNIQUE,
  
  -- Профильные данные
  name TEXT NOT NULL,
  avatar TEXT NOT NULL DEFAULT '',
  user_group INTEGER NOT NULL DEFAULT 0,
  
  -- Статистика
  total_distance INTEGER NOT NULL DEFAULT 0,
  total_activities INTEGER NOT NULL DEFAULT 0,
  total_time INTEGER NOT NULL DEFAULT 0,
  
  -- Метаданные
  cached_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Индекс для быстрого поиска по user_id
CREATE INDEX idx_profiles_user_id ON cached_profiles(user_id);

-- ────────────────────────── Таблица: cached_routes ──────────────────────────

CREATE TABLE cached_routes (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  
  activity_id INTEGER NOT NULL UNIQUE,
  
  -- GPS точки (массив координат)
  points TEXT NOT NULL DEFAULT '[]',
  
  -- Границы маршрута (для fit bounds)
  bounds TEXT NOT NULL DEFAULT '[]',
  
  -- Метаданные
  cached_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Индекс для быстрого поиска по activity_id
CREATE INDEX idx_routes_activity_id ON cached_routes(activity_id);

-- ────────────────────────── КОММЕНТАРИИ ──────────────────────────

-- Формат JSON для сложных типов:
--
-- equipments: [{"name":"Asics Gel","mileage":342,"img":"url","main":true,"myraiting":4.5,"type":"shoes"}]
-- stats: {"distance":10.5,"realDistance":10.52,"avgSpeed":12.3,...}
-- points: [{"lat":55.751244,"lng":37.618423},...]
-- media_images: ["https://cdn.paceup.ru/image1.jpg","https://cdn.paceup.ru/image2.jpg"]
-- media_videos: ["https://cdn.paceup.ru/video1.mp4"]
--
-- Drift автоматически конвертирует эти JSON строки в Dart объекты через TypeConverters.

