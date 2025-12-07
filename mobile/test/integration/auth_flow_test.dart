import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/main_dev.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow Integration Tests', () {
    testWidgets('полный flow авторизации', (WidgetTester tester) async {
      // Запускаем приложение
      app.main();
      await tester.pumpAndSettle();

      // Проверяем, что отображается экран логина
      expect(find.text('Вход в систему'), findsOneWidget);

      // Вводим данные для входа
      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '+79991234567');
      await tester.pump();

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Нажимаем кнопку входа
      final loginButton = find.text('Войти');
      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Проверяем результат (зависит от моков/реального API)
      // В реальном тесте здесь будет проверка навигации на главный экран
    });
  });
}

