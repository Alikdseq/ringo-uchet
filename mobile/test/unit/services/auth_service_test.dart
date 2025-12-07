import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../lib/features/auth/services/auth_service.dart';
import '../../../../lib/features/auth/models/auth_models.dart';
import '../../../../lib/core/errors/app_exception.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('AuthService', () {
    late MockDio mockDio;
    late ProviderContainer container;

    setUp(() {
      mockDio = MockDio();
      container = createTestContainer(dio: mockDio);
    });

    tearDown(() {
      container.dispose();
    });

    test('login успешно возвращает AuthResponse', () async {
      // Arrange
      final response = Response(
        data: TestData.authResponse,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/token/'),
      );
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => response);

      final service = container.read(authServiceProvider);
      final request = LoginRequest(
        phone: '+79991234567',
        password: 'password123',
      );

      // Act
      final result = await service.login(request);

      // Assert
      expect(result.access, equals('test_access_token'));
      expect(result.refresh, equals('test_refresh_token'));
      expect(result.user, isNotNull);
      expect(result.user?.id, equals(1));
    });

    test('login выбрасывает UnauthorizedException при 401', () async {
      // Arrange
      final response = Response(
        data: {'detail': 'Invalid credentials'},
        statusCode: 401,
        requestOptions: RequestOptions(path: '/api/token/'),
      );
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/token/'),
        response: response,
        type: DioExceptionType.badResponse,
      ));

      final service = container.read(authServiceProvider);
      final request = LoginRequest(
        phone: '+79991234567',
        password: 'wrong_password',
      );

      // Act & Assert
      expect(
        () => service.login(request),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('refreshToken успешно обновляет токен', () async {
      // Arrange
      final response = Response(
        data: {'access': 'new_access_token'},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/token/refresh/'),
      );
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => response);

      final service = container.read(authServiceProvider);

      // Act
      final newToken = await service.refreshToken('refresh_token');

      // Assert
      expect(newToken, equals('new_access_token'));
    });

    test('logout успешно отзывает токены', () async {
      // Arrange
      final response = Response(
        data: {},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/token/blacklist/'),
      );
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => response);

      final service = container.read(authServiceProvider);

      // Act & Assert
      await expectLater(
        service.logout('refresh_token'),
        completes,
      );
    });
  });
}

