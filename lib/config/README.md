# 🔧 Конфигурация приложения

Эта директория содержит файлы конфигурации приложения с **чувствительными данными** (API-ключи, токены, URL).

## 📝 Первый запуск

1. **Скопируйте файл-шаблон:**
   ```bash
   cp app_config.example.dart app_config.dart
   ```

2. **Получите API-ключи:**
   - **MapTiler**: [https://www.maptiler.com/](https://www.maptiler.com/)
     - Зарегистрируйтесь → Cloud → API Keys → Create new key
     - Замените `YOUR_MAPTILER_API_KEY` на полученный ключ

3. **Обновите `app_config.dart`:**
   ```dart
   static const String mapTilerApiKey = 'ВАШ_РЕАЛЬНЫЙ_КЛЮЧ_ЗДЕСЬ';
   ```

## ⚠️ ВАЖНО

- **НЕ коммитьте `app_config.dart` в репозиторий!**
- Файл уже добавлен в `.gitignore`
- Используйте `app_config.example.dart` как шаблон для новых разработчиков
- Храните реальные ключи в безопасности

## 🔑 Список секретов

| Переменная | Описание | Где получить |
|---|---|---|
| `mapTilerApiKey` | API-ключ для MapTiler (карты) | [maptiler.com](https://www.maptiler.com/) |
| `baseUrl` | URL бэкенда | От DevOps команды |

## 🚀 Production

Для production-сборки используйте environment variables или Flutter flavors.

### Пример с Flutter flavors:

```dart
class AppConfig {
  static const String mapTilerApiKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: 'dev-key',
  );
}
```

Запуск:
```bash
flutter build apk --dart-define=MAPTILER_API_KEY=your-prod-key
```

---

**Вопросы?** Обратитесь к тех. лиду проекта.

