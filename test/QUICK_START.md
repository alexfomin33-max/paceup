# 🚀 Быстрый старт тестирования

## Установка

```bash
flutter pub get
```

## Запуск тестов

```bash
# Все тесты
flutter test

# Конкретный тест
flutter test test/unit/services/auth_service_test.dart
```

## Создание нового теста

### 1. Unit тест для сервиса

Создайте файл `test/unit/services/your_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:paceup/core/services/your_service.dart';
import 'package:paceup/test/helpers/mocks/mock_api_service.dart';

void main() {
  group('YourService', () {
    late YourService service;
    late MockApiService mockApi;

    setUp(() {
      mockApi = MockApiServiceFactory.successful();
      service = YourService(api: mockApi);
    });

    test('метод работает корректно', () async {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

### 2. Widget тест

Создайте файл `test/widget/core/your_widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paceup/test/helpers/provider_helpers.dart';

void main() {
  testWidgets('Widget отображает данные', (tester) async {
    // Arrange
    final container = ProviderTestHelpers.createTestContainer();

    // Act
    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: YourWidget(),
      ),
    );

    // Assert
    expect(find.text('Expected Text'), findsOneWidget);
    
    container.dispose();
  });
}
```

## Полезные ссылки

- Полная документация: `test/README.md`
- Примеры использования: `test/widget_test.dart`
- Хелперы: `test/helpers/README.md`
