import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_helpers.dart';

void main() {
  // Инициализация тестового окружения
  setUpAll(() {
    initTestDatabase();
  });

  // Запуск всех тестов
  group('All Tests', () {
    // Unit тесты
    test('placeholder', () {
      expect(true, isTrue);
    });
  });
}

