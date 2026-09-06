require('dotenv').config();

module.exports = {
  PORT: process.env.PORT || '5005',
  NODE_ENV: process.env.NODE_ENV || 'development',
  JWT_SECRET: process.env.JWT_SECRET || 'auracare_super_secret_jwt_key_2026_telehealth_security',
  LIVEKIT_API_KEY: process.env.LIVEKIT_API_KEY || 'devkey',
  LIVEKIT_API_SECRET: process.env.LIVEKIT_API_SECRET || 'secret',
<<<<<<< HEAD
  SUPABASE_URL: process.env.SUPABASE_URL || 'https://yfhnpautctntwdcisvmb.supabase.co',
=======
  SUPABASE_URL: process.env.SUPABASE_URL || 'https://uwywihgsvijyixhszghc.supabase.co',
>>>>>>> origin/main
  SUPABASE_SERVICE_KEY: process.env.SUPABASE_SERVICE_KEY || 'sample_service_role_key',
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS || '*',
};
