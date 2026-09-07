class AppConfig {
  // Backend base URL is injected at build time via:
  //   flutter run --dart-define=API_BASE_URL=https://your-backend.example.com
  // Defaults to localhost for `flutter run` on the same machine as the backend.
  static const String baseApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5005/api',
  );
}

class LiveKitConfig {
  // LiveKit server URL is injected at build time via:
  //   flutter run --dart-define=LIVEKIT_URL=wss://your-app.livekit.cloud
  static const String serverUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://tele-qta84c5k.livekit.cloud',
  );
  static const String apiKey = String.fromEnvironment(
    'LIVEKIT_API_KEY',
    defaultValue: 'APIjazQB9UmJJdg',
  );
  static const String apiSecret = String.fromEnvironment(
    'LIVEKIT_API_SECRET',
    defaultValue: 'Bp2ifhyMjeqNVZIoVkNRDMfan8X5pGSe7fmLgqtPR5TF',
  );
}

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://chav-telehealth.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_anon_key_chav_telehealth_storage_2026',
  );
  static const String bucket = 'chav';
  static const String prefix = 'biometric_captures';
}
