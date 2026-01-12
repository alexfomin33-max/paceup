// ────────────────────────────────────────────────────────────────────────────
//  WIDGET TESTS: PrimaryButton
//
//  Тесты для основной кнопки приложения:
//  • Отображение текста
//  • Состояния (enabled, disabled, loading)
//  • Обработка нажатий
//  • Размеры и стили
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceup/core/widgets/primary_button.dart';

void main() {
  group('PrimaryButton', () {
    // ────────────────────────────────────────────────────────────
    // Тесты для базового отображения
    // ────────────────────────────────────────────────────────────

    testWidgets('отображает текст кнопки', (tester) async {
      // Arrange
      const buttonText = 'Нажми меня';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: buttonText,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(buttonText), findsOneWidget);
    });

    testWidgets('вызывает onPressed при нажатии', (tester) async {
      // Arrange
      var pressed = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      // Assert
      expect(pressed, isTrue);
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для состояний
    // ────────────────────────────────────────────────────────────

    testWidgets('блокирует нажатия когда disabled', (tester) async {
      // Arrange
      var pressed = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () => pressed = true,
              enabled: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      // Assert
      expect(pressed, isFalse);
    });

    testWidgets('показывает индикатор загрузки когда isLoading', (tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Загрузка',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Загрузка'), findsOneWidget);
    });

    testWidgets('блокирует нажатия когда isLoading', (tester) async {
      // Arrange
      var pressed = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Загрузка',
              onPressed: () => pressed = true,
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      // Assert
      expect(pressed, isFalse);
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для размеров
    // ────────────────────────────────────────────────────────────

    testWidgets('растягивается на всю ширину когда expanded', (tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () {},
              expanded: true,
            ),
          ),
        ),
      );

      // Assert
      final button = tester.getSize(find.byType(PrimaryButton));
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(button.width, screenWidth);
    });

    testWidgets('использует заданную ширину когда width указан', (tester) async {
      // Arrange
      const customWidth = 200.0;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () {},
              width: customWidth,
            ),
          ),
        ),
      );

      // Assert
      final button = tester.getSize(find.byType(PrimaryButton));
      expect(button.width, customWidth);
    });

    testWidgets('использует заданную высоту', (tester) async {
      // Arrange
      const customHeight = 50.0;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () {},
              height: customHeight,
            ),
          ),
        ),
      );

      // Assert
      final button = tester.getSize(find.byType(PrimaryButton));
      expect(button.height, customHeight);
    });

    // ────────────────────────────────────────────────────────────
    // Тесты для иконок
    // ────────────────────────────────────────────────────────────

    testWidgets('отображает leading иконку', (tester) async {
      // Arrange
      const icon = Icon(Icons.add);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () {},
              leading: icon,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('отображает trailing иконку', (tester) async {
      // Arrange
      const icon = Icon(Icons.arrow_forward);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Кнопка',
              onPressed: () {},
              trailing: icon,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('скрывает иконки когда isLoading', (tester) async {
      // Arrange
      const leadingIcon = Icon(Icons.add);
      const trailingIcon = Icon(Icons.arrow_forward);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Загрузка',
              onPressed: () {},
              isLoading: true,
              leading: leadingIcon,
              trailing: trailingIcon,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });
  });
}
