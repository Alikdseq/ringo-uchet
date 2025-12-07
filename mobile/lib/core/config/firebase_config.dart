/// Конфигурация Firebase для разных flavors
class FirebaseConfig {
  final String androidGoogleServicesPath;
  final String iosGoogleServicesPath;
  final bool enabled;

  const FirebaseConfig({
    required this.androidGoogleServicesPath,
    required this.iosGoogleServicesPath,
    required this.enabled,
  });

  static FirebaseConfig get dev => const FirebaseConfig(
        androidGoogleServicesPath: 'android/app/google-services-dev.json',
        iosGoogleServicesPath: 'ios/Runner/GoogleService-Info-Dev.plist',
        enabled: false, // Можно отключить для dev
      );

  static FirebaseConfig get stage => const FirebaseConfig(
        androidGoogleServicesPath: 'android/app/google-services-stage.json',
        iosGoogleServicesPath: 'ios/Runner/GoogleService-Info-Stage.plist',
        enabled: true,
      );

  static FirebaseConfig get prod => const FirebaseConfig(
        androidGoogleServicesPath: 'android/app/google-services-prod.json',
        iosGoogleServicesPath: 'ios/Runner/GoogleService-Info-Prod.plist',
        enabled: true,
      );
}

