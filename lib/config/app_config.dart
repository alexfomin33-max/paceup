// ────────────────────────────────────────────────────────────────────────────
//  КОНФИГУРАЦИЯ ПРИЛОЖЕНИЯ
//
//  ⚠️ ВАЖНО: Этот файл содержит чувствительные данные (API-ключи)
//  ⚠️ НЕ КОММИТЬТЕ этот файл в публичный репозиторий!
//  ⚠️ Используйте app_config.example.dart как шаблон
// ────────────────────────────────────────────────────────────────────────────

class AppConfig {
  // ────────────────────────── API URLs ──────────────────────────

  /// Базовый URL бэкенда
  static const String baseUrl = "http://api.paceup.ru";

  // ────────────────────────── Map Tiles ──────────────────────────

  /// MapTiler API ключ для отображения карт (OSM)
  /// Получить ключ: https://www.maptiler.com/
  static const String mapTilerApiKey = '5Ssg96Nz79IHOCKB0MLL';

  /// URL для тайлов карты
  static const String mapTilesUrl =
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={apiKey}';

  // ────────────────────────── Network Settings ──────────────────────────

  /// Таймаут по умолчанию для HTTP-запросов
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Количество повторных попыток при сетевых ошибках
  static const int maxRetries = 3;

  /// Базовая задержка для exponential backoff (в миллисекундах)
  /// Формула: delay = retryBaseDelayMs * 2^(attempt-1)
  /// • Попытка 1→2: 500ms
  /// • Попытка 2→3: 1000ms (1 сек)
  /// • Попытка 3→4: 2000ms (2 сек)
  static const int retryBaseDelayMs = 500;

  // ────────────────────────── Connection Pooling ──────────────────────────

  /// Максимальное количество параллельных соединений к одному хосту
  ///
  /// 6 соединений — оптимальное значение для мобильных приложений:
  /// • Соответствует рекомендации HTTP/1.1 (RFC 7230)
  /// • Баланс между скоростью загрузки и потреблением памяти
  /// • Позволяет параллельно загружать изображения и API запросы
  static const int maxConnectionsPerHost = 6;

  /// Таймаут установки TCP соединения (handshake)
  ///
  /// 5 секунд — быстрое обнаружение недоступных серверов:
  /// • Предотвращает "зависание" UI при проблемах с сетью
  /// • Достаточно для медленных мобильных сетей (3G/4G)
  /// • Быстрее fallback на кэш в offline режиме
  static const Duration connectionTimeout = Duration(seconds: 5);

  /// Время жизни idle соединения в connection pool (Keep-Alive)
  ///
  /// 60 секунд — баланс между переиспользованием и памятью:
  /// • Переиспользование соединений снижает latency на 25-30%
  /// • Экономия на TCP handshake и TLS handshake
  /// • После 60 сек соединение автоматически закрывается
  /// • Соответствует стандартному Keep-Alive timeout большинства серверов
  static const Duration idleTimeout = Duration(seconds: 60);

  // ────────────────────────── App Info ──────────────────────────

  /// Название приложения
  static const String appName = 'PaceUp';

  /// Версия приложения
  static const String appVersion = '1.0.0';

  // ────────────────────────── Debug Mode ──────────────────────────

  /// Режим отладки (показывать подробные логи)
  static const bool debugMode = false;
}
