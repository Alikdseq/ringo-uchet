import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ringo_mobile/core/config/sentry_config.dart';
import 'package:ringo_mobile/core/config/firebase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  final firebaseConfig = FirebaseConfig.prod;
  if (firebaseConfig.enabled) {
    await Firebase.initializeApp();
  }

  // Инициализация Sentry (должна быть после Firebase)
  await SentryConfig.init();

  runApp(
    const ProviderScope(
      child: RingoApp(),
    ),
  );
}
