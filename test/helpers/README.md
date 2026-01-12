# Test Helpers

Вспомогательные утилиты для тестирования.

## Структура

```
helpers/
├── test_utils.dart          # Общие утилиты
├── provider_helpers.dart    # Хелперы для Riverpod
├── mocks/                   # Моки для сервисов
└── fixtures/               # Фикстуры для тестовых данных
```

## Использование

### TestUtils

```dart
import 'package:paceup/test/helpers/test_utils.dart';

// Создание тестовых дат
final date = TestUtils.testDate(daysOffset: -1);

// Создание тестового JSON
final json = TestUtils.createTestJson(overrides: {'key': 'value'});
```

### ProviderTestHelpers

```dart
import 'package:paceup/test/helpers/provider_helpers.dart';

// Создание тестового контейнера
final container = ProviderTestHelpers.createTestContainer(
  overrides: [/* ... */],
);
```

### Моки

```dart
import 'package:paceup/test/helpers/mocks/mock_auth_service.dart';
import 'package:paceup/test/helpers/mocks/mock_api_service.dart';
import 'package:paceup/test/helpers/mocks/mock_cache_service.dart';

// Используйте Factory классы для создания моков
final mockAuth = MockAuthServiceFactory.authorized();
final mockApi = MockApiServiceFactory.successful();
final mockCache = MockCacheServiceFactory.empty();
```

### Фикстуры

```dart
import 'package:paceup/test/helpers/fixtures/activity_fixtures.dart';
import 'package:paceup/test/helpers/fixtures/user_fixtures.dart';
import 'package:paceup/test/helpers/fixtures/api_response_fixtures.dart';

// Создание тестовых данных
final activity = ActivityFixtures.createRunningActivity();
final user = UserFixtures.createUser();
final response = ApiResponseFixtures.success();
```
