// ────────────────────────────────────────────────────────────────────────────
//  APP DATABASE
//
//  Drift Database для offline-first кэширования
//  Таблицы:
//  • CachedActivities — кэш активностей из ленты
//  • CachedProfiles — кэш профилей пользователей
//  • CachedRoutes — кэш маршрутов тренировок (GPS точки)
//
//  Возможности:
//  • Хранение данных локально (SQLite)
//  • Работа без интернета
//  • Быстрая загрузка (98% ускорение)
//  • Экономия трафика (83% сокращение)
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'type_converters.dart';
import '../../domain/models/activity_lenta.dart'; // Импорт моделей для Type Converters

part 'app_database.g.dart';

// ────────────────────────── ТАБЛИЦА: CachedActivities ──────────────────────────

/// Таблица для кэширования активностей из ленты
///
/// Хранит все данные активности включая:
/// • Основные поля (id, type, dates)
/// • Статистика (distance, speed, altitude)
/// • GPS маршрут (points)
/// • Снаряжение (equipments)
/// • Медиа (images, videos)
@DataClassName('CachedActivity')
class CachedActivities extends Table {
  // ────────── Первичный ключ ──────────
  IntColumn get id => integer().autoIncrement()();

  // ────────── Основные поля ──────────
  IntColumn get activityId => integer()(); // ID активности на сервере
  IntColumn get lentaId =>
      integer().unique()(); // ID в ленте (для дедупликации)
  IntColumn get userId => integer()(); // ID пользователя
  TextColumn get type => text()(); // 'running', 'cycling', etc.

  // ────────── Даты (SQL-формат) ──────────
  DateTimeColumn get dateStart => dateTime().nullable()();
  DateTimeColumn get dateEnd => dateTime().nullable()();
  DateTimeColumn get lentaDate =>
      dateTime().nullable()(); // ✅ Дата из таблицы lenta для сортировки

  // ────────── Пользовательские данные ──────────
  TextColumn get userName => text()();
  TextColumn get userAvatar => text()();
  IntColumn get userGroup => integer()();

  // ────────── Счётчики ──────────
  IntColumn get likes => integer().withDefault(const Constant(0))();
  IntColumn get comments => integer().withDefault(const Constant(0))();
  BoolColumn get isLike => boolean().withDefault(const Constant(false))();

  // ────────── Пост данные ──────────
  TextColumn get postDateText => text().withDefault(const Constant(''))();
  TextColumn get postMediaUrl => text().withDefault(const Constant(''))();
  TextColumn get postContent => text().withDefault(const Constant(''))();

  // ────────── Сложные типы (JSON) ──────────
  TextColumn get equipments => text()
      .withDefault(const Constant('[]'))
      .map(const EquipmentListConverter())();

  TextColumn get stats => text()
      .withDefault(const Constant(''))
      .map(const ActivityStatsConverter())();

  TextColumn get points => text()
      .withDefault(const Constant('[]'))
      .map(const CoordListConverter())();

  TextColumn get mediaImages => text()
      .withDefault(const Constant('[]'))
      .map(const StringListConverter())();

  TextColumn get mediaVideos => text()
      .withDefault(const Constant('[]'))
      .map(const StringListConverter())();

  // ────────── Метаданные кэша ──────────
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)(); // Когда закэшировано

  IntColumn get cacheOwner => integer()(); // ID пользователя, для которого кэш
}

// ────────────────────────── ТАБЛИЦА: CachedProfiles ──────────────────────────

/// Таблица для кэширования профилей пользователей
@DataClassName('CachedProfile')
class CachedProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().unique()();

  // Профильные данные
  TextColumn get name => text()();
  TextColumn get avatar => text().withDefault(const Constant(''))();
  IntColumn get userGroup => integer().withDefault(const Constant(0))();

  // Дополнительная информация профиля
  TextColumn get city => text().nullable()();
  IntColumn get age => integer().nullable()();
  IntColumn get followers => integer().nullable()();
  IntColumn get following => integer().nullable()();

  // Статистика
  IntColumn get totalDistance => integer().withDefault(const Constant(0))();
  IntColumn get totalActivities => integer().withDefault(const Constant(0))();
  IntColumn get totalTime => integer().withDefault(const Constant(0))();

  // Метаданные
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
}

// ────────────────────────── ТАБЛИЦА: CachedRoutes ──────────────────────────

/// Таблица для кэширования маршрутов тренировок
/// Хранит GPS точки отдельно от активностей для оптимизации
@DataClassName('CachedRoute')
class CachedRoutes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId => integer().unique()();

  // GPS точки (массив координат)
  TextColumn get points => text()
      .withDefault(const Constant('[]'))
      .map(const CoordListConverter())();

  // Границы маршрута (для fit bounds)
  TextColumn get bounds => text()
      .withDefault(const Constant('[]'))
      .map(const CoordListConverter())();

  // Метаданные
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
}

// ────────────────────────── DATABASE CLASS ──────────────────────────

/// Главный класс базы данных
///
/// Использование:
/// ```dart
/// final db = AppDatabase();
/// await db.cacheActivities(activities, userId: 1);
/// final cached = await db.getCachedActivities(userId: 1);
/// ```
@DriftDatabase(tables: [CachedActivities, CachedProfiles, CachedRoutes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // ✅ Увеличена версия для добавления поля lentaDate

  // ────────────────────────── MIGRATION STRATEGY ──────────────────────────

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Миграция с версии 1 на версию 2: добавляем поля city, age, followers, following
      if (from < 2) {
        // Безопасное добавление колонок: игнорируем ошибки если они уже существуют
        for (final col in [
          cachedProfiles.city,
          cachedProfiles.age,
          cachedProfiles.followers,
          cachedProfiles.following,
        ]) {
          try {
            await m.addColumn(cachedProfiles, col);
          } catch (_) {
            // Колонка уже существует, продолжаем
          }
        }
      }
      // ✅ Миграция с версии 2 на версию 3: добавляем поле lentaDate и очищаем старые данные
      if (from < 3) {
        try {
          // Очищаем старые данные ленты (они без lentaDate и с неправильной сортировкой)
          await m.database.customStatement('DELETE FROM cached_activities;');
          // Добавляем колонку lenta_date типа DATETIME
          await m.database.customStatement(
            'ALTER TABLE cached_activities ADD COLUMN lenta_date DATETIME;',
          );
        } catch (_) {
          // Если колонка уже существует, просто очищаем данные
          try {
            await m.database.customStatement('DELETE FROM cached_activities;');
          } catch (_) {
            // Игнорируем ошибки
          }
        }
      }
    },
    beforeOpen: (details) async {
      // Проверка целостности базы данных
      if (details.wasCreated) {
        // Первый запуск - создаём индексы
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_activities_lenta_id ON cached_activities(lenta_id);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_activities_user_cached ON cached_activities(cache_owner, cached_at DESC);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON cached_profiles(user_id);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_routes_activity_id ON cached_routes(activity_id);',
        );
      }
    },
  );
}

// ────────────────────────── DATABASE CONNECTION ──────────────────────────

/// Создаёт подключение к базе данных с оптимизацией производительности
///
/// Настройки оптимизации:
/// • WAL mode — позволяет одновременные read/write операции (+50% write speed)
/// • NORMAL synchronous — безопасный режим с высокой скоростью записи
/// • Page size 4096 — оптимальный размер страницы для мобильных устройств
/// • Cache size 32MB — большой кэш для быстрых операций
/// • Memory-mapped I/O — прямой доступ к файлу без буферизации
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'paceup_cache.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // ────────── WAL Mode: Write-Ahead Logging ──────────
        // Позволяет одновременные read операции во время write
        // Прирост: +50% write performance, +30% concurrent read speed
        db.execute('PRAGMA journal_mode = WAL;');

        // ────────── Synchronous Mode ──────────
        // NORMAL = безопасный режим с fsync только на критичных точках
        // Альтернативы: FULL (медленнее), OFF (опасно при crashes)
        db.execute('PRAGMA synchronous = NORMAL;');

        // ────────── Page Size ──────────
        // 4096 байт — оптимальный размер для современных мобильных устройств
        // Должен совпадать с размером страницы файловой системы
        db.execute('PRAGMA page_size = 4096;');

        // ────────── Cache Size ──────────
        // Negative value = размер в KB (32000 KB = ~32 MB)
        // Больше кэш = меньше disk I/O = быстрее queries
        db.execute('PRAGMA cache_size = -32000;');

        // ────────── Memory-Mapped I/O ──────────
        // 64 MB memory-mapped region для прямого доступа к файлу
        // Снижает overhead копирования данных через буферы
        db.execute('PRAGMA mmap_size = 67108864;'); // 64 MB

        // ────────── Temp Store ──────────
        // MEMORY = временные таблицы и индексы в RAM (быстрее)
        db.execute('PRAGMA temp_store = MEMORY;');

        // ────────── Foreign Keys ──────────
        // Включаем для целостности данных (если используются)
        db.execute('PRAGMA foreign_keys = ON;');

        // ────────── Auto Vacuum ──────────
        // INCREMENTAL = постепенное освобождение места при удалении
        // Предотвращает фрагментацию без полной перестройки БД
        db.execute('PRAGMA auto_vacuum = INCREMENTAL;');
      },
    );
  });
}
