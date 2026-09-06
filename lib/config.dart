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
  // Supabase Project: CHAV (Organization: Shalini_Org, Production)
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yfhnpautctntwdcisvmb.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmaG5wYXV0Y3RudHdkY2lzdm1iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1NjU3MTEsImV4cCI6MjA5OTE0MTcxMX0.X1InbmI1bxqkdtndrSf6RYkKM9Nqu75Gt3tSvy3t_c0',
  );

  // Biometric bucket (preserved)
  static const String bucket = 'chav';
  static const String prefix = 'biometric_captures';

  // Consultation Files Storage Configuration
  static const String consultationBucket = 'chav_consultation_files';
  static const String consultationFolder = 'consultation-files';
}
