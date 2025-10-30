# 🗄️ Database Migrations

Этот каталог содержит SQL скрипты для миграции схемы Drift Database.

## 📋 Структура

```
database_migrations/
├── README.md           # Этот файл
├── schema_v1.sql       # Начальная схема (версия 1)
├── migration_v2.sql    # Миграция с версии 1 на 2
└── migration_v3.sql    # Миграция с версии 2 на 3
```

## 🎯 Как работают миграции

### Версия 1 (текущая)

Начальная схема включает:
- `cached_activities` — кэш активностей из ленты
- `cached_profiles` — кэш профилей пользователей
- `cached_routes` — кэш GPS маршрутов

### Добавление новой миграции

1. **Увеличьте версию в `app_database.dart`:**
   ```dart
   @override
   int get schemaVersion => 2; // было 1
   ```

2. **Создайте файл миграции:**
   ```sql
   -- migration_v2.sql
   -- Миграция с версии 1 на 2
   
   -- Добавляем новую колонку
   ALTER TABLE cached_activities ADD COLUMN new_field TEXT DEFAULT '';
   
   -- Создаём новую таблицу
   CREATE TABLE cached_comments (
     id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
     activity_id INTEGER NOT NULL,
     comment_text TEXT NOT NULL,
     created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
   );
   ```

3. **Реализуйте миграцию в коде:**
   ```dart
   @override
   MigrationStrategy get migration => MigrationStrategy(
     onCreate: (Migrator m) async {
       await m.createAll();
     },
     onUpgrade: (Migrator m, int from, int to) async {
       if (from == 1 && to == 2) {
         // Читаем и выполняем SQL из файла
         await m.alterTable(TableMigration(
           cachedActivities,
           columnTransformer: {
             cachedActivities.newField: const Constant(''),
           },
         ));
       }
     },
   );
   ```

## ⚠️ Важные правила

1. **Никогда не изменяйте существующие миграции** — только добавляйте новые
2. **Тестируйте миграции** на разных версиях схемы
3. **Сохраняйте обратную совместимость** данных
4. **Документируйте изменения** в файлах миграций
5. **Используйте транзакции** для сложных миграций

## 📊 Проверка версии схемы

Чтобы узнать текущую версию схемы:

```dart
final db = AppDatabase();
final version = db.schemaVersion;
print('Current schema version: $version');
```

## 🔧 Полезные команды

```bash
# Генерация Drift кода после изменений схемы
dart run build_runner build --delete-conflicting-outputs

# Экспорт текущей схемы
dart run drift_dev schema dump lib/database/app_database.dart database_migrations/
```

## 📚 Ссылки

- [Drift Migrations Guide](https://drift.simonbinder.eu/docs/advanced-features/migrations/)
- [Database Migration Best Practices](https://drift.simonbinder.eu/docs/migrations/tests/)

