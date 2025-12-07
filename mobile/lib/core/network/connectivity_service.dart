import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдер сервиса подключения
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Состояние подключения
enum ConnectionStatus {
  connected,
  disconnected,
  unknown,
}

/// Сервис для отслеживания состояния сети
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamController<ConnectionStatus>? _statusController;
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityService() {
    _statusController = StreamController<ConnectionStatus>.broadcast();
    _init();
  }

  Future<void> _init() async {
    // Проверяем начальное состояние
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Подписываемся на изменения
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(ConnectivityResult result) {
    final status = result == ConnectivityResult.none
        ? ConnectionStatus.disconnected
        : ConnectionStatus.connected;
    _statusController?.add(status);
  }

  /// Поток изменений состояния подключения
  Stream<ConnectionStatus> get statusStream => _statusController!.stream;

  /// Текущее состояние подключения
  Future<ConnectionStatus> getCurrentStatus() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.none
        ? ConnectionStatus.disconnected
        : ConnectionStatus.connected;
  }

  /// Проверка наличия интернета
  Future<bool> hasConnection() async {
    final status = await getCurrentStatus();
    return status == ConnectionStatus.connected;
  }

  void dispose() {
    _subscription?.cancel();
    _statusController?.close();
  }
}

/// Провайдер текущего статуса подключения
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});

/// Провайдер проверки наличия подключения
final hasConnectionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(connectivityServiceProvider);
  return await service.hasConnection();
});

