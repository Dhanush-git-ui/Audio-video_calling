class AppConfig {
  static const String baseApiUrl = 'http://localhost:5005/api';
}

class LiveKitConfig {
  // Your LiveKit Cloud URL
  static const String serverUrl = 'wss://tele-qta84c5k.livekit.cloud';

  // Credentials used to sign tokens locally for testing
  static const String apiKey = 'APIjazQB9UmJJdg';
  static const String apiSecret = 'Bp2ifhyMjeqNVZIoVkNRDMfan8X5pGSe7fmLgqtPR5TF';
}

class SupabaseConfig {
  static const String url = 'https://chav-telehealth.supabase.co';
  static const String anonKey = 'sb_anon_key_chav_telehealth_storage_2026';
  static const String bucket = 'chav';
  static const String prefix = 'biometric_captures';
}
