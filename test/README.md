# 🧪 Инфраструктура тестирования

Полная инфраструктура для тестирования Flutter приложения PaceUp.

## 📁 Структура

```
test/
├── helpers/              # Вспомогательные утилиты
│   ├── test_utils.dart          # Общие утилиты для тестов
│   ├── provider_helpers.dart    # Хелперы для Riverpod
│   ├── mocks/                   # Моки для сервисов
│   │   ├── mock_auth_service.dart
│   │   ├── mock_api_service.dart
│   │   └── mock_cache_service.dart
│   └── fixtures/                # Фикстуры для тестовых данных
│       ├── activity_fixtures.dart
│       ├── user_fixtures.dart
│       └── api_response_fixtures.dart
├── unit/                 # Unit тесты
│   └── services/         # Тесты для сервисов
├── widget/               # Widget тесты
│   └── core/             # Тесты для виджетов
└── integration/          # Integration тесты
    └── flows/             # Тесты пользовательских сценариев
```

## 🚀 Быстрый старт

### 1. Установка зависимостей

```bash
flutter pub get
```

### 2. Запуск тестов

```bash
# Все тесты
flutter test

# Только unit тесты
flutter test test/unit/

# Только widget тесты
flutter test test/widget/

# Конкретный тест
flutter test test/unit/services/auth_service_test.dart
```

## 📝 Примеры использования

### Unit тесты для сервисов

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:paceup/core/services/auth_service.dart';
import 'package:paceup/test/helpers/mocks/mock_api_service.dart';
import 'package:paceup/test/helpers/fixtures/api_response_fixtures.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockApiService mockApi;

    setUp(() {
      mockApi = MockApiService.successful();
      authService = AuthService();
    });

    test('isAuthorized возвращает true при валидном токене', () async {
      // Arrange
      final mockApi = MockApiServiceFactory.withPostResponse(
        ApiResponseFixtures.tokenCheck(valid: true),
      );

      // Act
      final result = await authService.isAuthorized();

      // Assert
      expect(result, isTrue);
    });
  });
}
```

### Widget тесты

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paceup/test/helpers/provider_helpers.dart';
import 'package:paceup/test/helpers/mocks/mock_auth_service.dart';

void main() {
  testWidgets('Widget отображает данные', (tester) async {
    // Arrange
    final mockAuth = MockAuthService.authorized();
    final container = ProviderTestHelpers.createTestContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
      ],
    );

    // Act
    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: YourWidget(),
      ),
    );

    // Assert
    expect(find.text('Test User'), findsOneWidget);
  });
}
```

### Тесты для Riverpod провайдеров

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paceup/test/helpers/provider_helpers.dart';
import 'package:paceup/test/helpers/mocks/mock_api_service.dart';

void main() {
  group('lentaProvider', () {
    test('загружает активности', () async {
      // Arrange
      final mockApi = MockApiServiceFactory.withGetResponse(
        ApiResponseFixtures.withList(items: []),
      );
      final container = ProviderTestHelpers.createTestContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
        ],
      );

      // Act
      final provider = lentaProvider(1);
      final result = await container.read(provider.future);

      // Assert
      expect(result, isA<List>());
      
      container.dispose();
    });
  });
}
```

## 🛠️ Доступные хелперы

### TestUtils

```dart
// Создание тестовых дат
final date = TestUtils.testDate(daysOffset: -1);

// Создание тестового JSON
final json = TestUtils.createTestJson(overrides: {'key': 'value'});

// Ожидание асинхронных операций
await TestUtils.waitForAsync();
```

### ProviderTestHelpers

```dart
// Создание тестового контейнера
final container = ProviderTestHelpers.createTestContainer(
  overrides: [/* ... */],
);

// Проверка состояний провайдера
ProviderTestHelpers.expectProviderData(container, provider);
ProviderTestHelpers.expectProviderLoading(container, provider);
ProviderTestHelpers.expectProviderError(container, provider);
```

### Фикстуры

```dart
// Активности
final activity = ActivityFixtures.createRunningActivity();
final activities = ActivityFixtures.createActivityList(count: 5);

// Пользователи
final user = UserFixtures.createUser();
final users = UserFixtures.createUserList(count: 10);

// API ответы
final response = ApiResponseFixtures.success();
final errorResponse = ApiResponseFixtures.error(message: 'Error');
```

### Моки

```dart
// AuthService
final mockAuth = MockAuthServiceFactory.authorized(userId: 1);
final mockAuthUnauthorized = MockAuthServiceFactory.unauthorized();

// ApiService
final mockApi = MockApiServiceFactory.successful();
final mockApiError = MockApiServiceFactory.withError('Network error');

// CacheService
final mockCache = MockCacheServiceFactory.withActivities(activities);
final mockCacheEmpty = MockCacheServiceFactory.empty();
```

## 📊 Покрытие кода

Для генерации отчёта о покрытии:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 🔄 CI/CD интеграция

Тесты автоматически запускаются в CI/CD при каждом коммите.

Пример для GitHub Actions:

```yaml
- name: Run tests
  run: flutter test --coverage
```

## 📚 Дополнительные ресурсы

- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [Riverpod Testing](https://riverpod.dev/docs/concepts/testing)
- [Mocktail Documentation](https://pub.dev/packages/mocktail)

**Примечание:** Для тестирования Riverpod провайдеров используем стандартные инструменты Flutter Test с хелперами из `provider_helpers.dart`.

## ⚠️ Важные замечания

1. **Изоляция тестов**: Каждый тест должен быть независимым
2. **Очистка**: Используйте `setUp` и `tearDown` для подготовки и очистки
3. **Моки**: Всегда используйте моки для внешних зависимостей
4. **Фикстуры**: Используйте фикстуры для создания тестовых данных
5. **Асинхронность**: Правильно обрабатывайте асинхронные операции

## 🎯 Приоритеты тестирования

1. **Критичная бизнес-логика** (авторизация, платежи)
2. **Сервисы** (API, кэш, авторизация)
3. **Провайдеры** (state management)
4. **Виджеты** (UI компоненты)
5. **Integration** (полные пользовательские сценарии)
