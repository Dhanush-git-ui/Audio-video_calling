import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  PORT: process.env.PORT || '3000',
  NODE_ENV: process.env.NODE_ENV || 'development',
  JWT_SECRET: process.env.JWT_SECRET || 'prachtiz-auracare-secret-jwt-key-2026',
  LIVEKIT_API_KEY: process.env.LIVEKIT_API_KEY || 'API4b3qXf8sU',
  LIVEKIT_API_SECRET: process.env.LIVEKIT_API_SECRET || 'sec_4b3qXf8sU987654321',
  LIVEKIT_URL: process.env.LIVEKIT_URL || 'wss://tele-qta84c5k.livekit.cloud',
  SUPABASE_URL: process.env.SUPABASE_URL || 'https://mock.supabase.co',
  SUPABASE_SERVICE_KEY: process.env.SUPABASE_SERVICE_KEY || 'mock-service-key',
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS || '*',
};
