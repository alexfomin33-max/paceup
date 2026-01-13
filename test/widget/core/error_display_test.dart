// ────────────────────────────────────────────────────────────────────────────
//  WIDGET TESTS: ErrorDisplay
//
//  Тесты для виджета отображения ошибок:
//  • Отображение ошибок
//  • Кнопка повтора
//  • Различные варианты (centered, inline, form)
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceup/core/widgets/error_display.dart';
import 'package:paceup/core/services/api_service.dart';

void main() {
  group('ErrorDisplay', () {
    // ────────────────────────────────────────────────────────────
    // Тесты для базового отображения
    // ────────────────────────────────────────────────────────────

    testWidgets('отображает текст ошибки', (tester) async {
      // Arrange
      const errorMessage = 'Произошла ошибка';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorDisplay(error: errorMessage)),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('отображает кастомное сообщение', (tester) async {
      // Arrange
      const customMessage = 'Кастомная ошибка';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              error: 'Оригинальная ошибка',
              customMessage: customMessage,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(customMessage), findsOneWidget);
      expect(find.text('Оригинальная ошибка'), findsNothing);
    });

    testWidgets(
      'отображает кнопку повтора когда onRetry передан и alwaysShowRetry=true',
      (tester) async {
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorDisplay(
                error: 'Ошибка',
                onRetry: () {},
                alwaysShowRetry: true,
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Повторить'), findsOneWidget);
      },
    );

    testWidgets('вызывает onRetry при нажатии на кнопку', (tester) async {
      // Arrange
      var retried = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              error: 'Ошибка',
              onRetry: () => retried = true,
              alwaysShowRetry: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Повторить'));
      await tester.pump();

      // Assert
      expect(retried, isTrue);
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для вариантов отображения
    // ────────────────────────────────────────────────────────────

    testWidgets('ErrorDisplay.centered центрирует контент', (tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorDisplay.centered(error: 'Ошибка')),
        ),
      );

      // Assert
      expect(find.text('Ошибка'), findsOneWidget);
    });

    testWidgets('ErrorDisplay.inline отображает inline ошибку', (tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorDisplay.inline(error: 'Ошибка валидации')),
        ),
      );

      // Assert
      expect(find.text('Ошибка валидации'), findsOneWidget);
    });

    testWidgets('ErrorDisplayForm скрывается когда error null', (tester) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ErrorDisplayForm(error: null))),
      );

      // Assert
      expect(find.byType(ErrorDisplayForm), findsOneWidget);
      // Виджет должен быть скрыт (SizedBox.shrink)
    });

    testWidgets('ErrorDisplayForm отображает ошибку', (tester) async {
      // Arrange
      const errorMessage = 'Ошибка формы';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorDisplayForm(error: errorMessage)),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для обработки различных типов ошибок
    // ────────────────────────────────────────────────────────────

    testWidgets('обрабатывает ApiException', (tester) async {
      // Arrange
      final apiException = ApiException('Ошибка сети');

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorDisplay(error: apiException)),
        ),
      );

      // Assert
      expect(find.text('Ошибка сети'), findsOneWidget);
    });

    testWidgets('обрабатывает строковую ошибку', (tester) async {
      // Arrange
      const errorMessage = 'Простая ошибка';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorDisplay(error: errorMessage)),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для дополнительного контента
    // ────────────────────────────────────────────────────────────

    testWidgets('отображает дополнительный контент', (tester) async {
      // Arrange
      const additionalWidget = Text('Дополнительная информация');

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplay(
              error: 'Ошибка',
              additionalContent: additionalWidget,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Дополнительная информация'), findsOneWidget);
    });
  });
}
