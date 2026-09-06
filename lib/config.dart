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
  // No API key/secret is ever shipped with the client — the backend mints tokens.
  static const String serverUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://tele-qta84c5k.livekit.cloud',
  );
}

class SupabaseConfig {
  // Supabase details are loaded from the backend at runtime; the client never
  // talks to Supabase directly.
  static const String url = '';
  static const String anonKey = '';
  static const String bucket = 'chav';
  static const String prefix = 'biometric_captures';
}
