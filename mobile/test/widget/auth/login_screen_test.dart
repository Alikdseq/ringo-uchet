import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringo_mobile/features/auth/screens/login_screen.dart';
import 'package:ringo_mobile/features/auth/providers/auth_providers.dart';
import 'package:ringo_mobile/core/config/app_config.dart';
import 'package:ringo_mobile/core/network/dio_client.dart';
import 'package:ringo_mobile/core/storage/secure_storage.dart';
import 'package:ringo_mobile/features/auth/services/auth_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('отображает поля для ввода телефона и пароля',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
      expect(find.text('Телефон'), findsOneWidget);
      expect(find.text('Пароль'), findsOneWidget);
    });

    testWidgets('показывает ошибку при пустом пароле',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Act
      final passwordField = find.byType(TextField).last;
      await tester.tap(passwordField);
      await tester.enterText(passwordField, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Assert
      expect(find.text('Введите пароль'), findsOneWidget);
    });

    testWidgets('переключается между режимами пароль/OTP',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Act - переключение на OTP
      final otpButton = find.text('OTP');
      await tester.tap(otpButton);
      await tester.pump();

      // Assert
      expect(find.text('Отправить код'), findsOneWidget);
    });
  });
}
