import 'package:flutter/foundation.dart' show debugPrint;
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

  try {
    // Инициализация Hive
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('Hive initialization error (non-critical): $e');
  }

  try {
    // Инициализация Firebase (если включен)
    final firebaseConfig = FirebaseConfig.dev;
    if (firebaseConfig.enabled) {
      await Firebase.initializeApp();
      // FCM будет инициализирован в app.dart после создания ProviderScope
    }
  } catch (e) {
    debugPrint('Firebase initialization error (non-critical): $e');
  }

  try {
    // Инициализация Local Storage
    final localStorage = LocalStorage();
    await localStorage.init();
  } catch (e) {
    debugPrint('LocalStorage initialization error (non-critical): $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        // Переопределяем конфигурацию для dev flavor
        appConfigProvider.overrideWithValue(AppConfig.dev),
      ],
      child: const RingoApp(),
    ),
  );
}
