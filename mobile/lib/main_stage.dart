import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/app_config.dart';
import 'core/config/firebase_config.dart';
import 'core/network/dio_client.dart';
import 'core/storage/local_storage.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive
  await Hive.initFlutter();

  // Инициализация Firebase
  final firebaseConfig = FirebaseConfig.stage;
  if (firebaseConfig.enabled) {
    await Firebase.initializeApp();
  }

  // Инициализация Local Storage
  final localStorage = LocalStorage();
  await localStorage.init();

  runApp(
    ProviderScope(
      overrides: [
        // Переопределяем конфигурацию для stage flavor
        appConfigProvider.overrideWithValue(AppConfig.stage),
      ],
      child: const RingoApp(),
    ),
  );
}

