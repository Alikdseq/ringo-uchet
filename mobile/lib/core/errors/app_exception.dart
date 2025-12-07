/// Базовый класс для исключений приложения
abstract class AppException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  const AppException(this.message, [this.errors]);

  // Фабричные конструкторы для разных типов ошибок
  factory AppException.network(String message) => NetworkException(message);
  factory AppException.timeout(String message) => TimeoutException(message);
  factory AppException.badRequest(String message) => BadRequestException(message);
  factory AppException.unauthorized(String message) => UnauthorizedException(message);
  factory AppException.forbidden(String message) => ForbiddenException(message);
  factory AppException.notFound(String message) => NotFoundException(message);
  factory AppException.validation(String message, [Map<String, dynamic>? errors]) =>
      ValidationException(message, errors);
  factory AppException.rateLimit(String message) => RateLimitException(message);
  factory AppException.server(String message) => ServerException(message);
  factory AppException.cancelled(String message) => CancelledException(message);
  factory AppException.unknown(String message) => UnknownException(message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class TimeoutException extends AppException {
  const TimeoutException(super.message);
}

class BadRequestException extends AppException {
  const BadRequestException(super.message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message);
}

class ForbiddenException extends AppException {
  const ForbiddenException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message, super.errors);
}

class RateLimitException extends AppException {
  const RateLimitException(super.message);
}

class ServerException extends AppException {
  const ServerException(super.message);
}

class CancelledException extends AppException {
  const CancelledException(super.message);
}

class UnknownException extends AppException {
  const UnknownException(super.message);
}

