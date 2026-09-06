import dotenv from 'dotenv';
dotenv.config();

export const ENV = {
  PORT: process.env.PORT || '5005',
  NODE_ENV: process.env.NODE_ENV || 'development',
  JWT_SECRET: process.env.JWT_SECRET ?? (() => { throw new Error('JWT_SECRET env var required'); })(),
  LIVEKIT_API_KEY: process.env.LIVEKIT_API_KEY ?? (() => { throw new Error('LIVEKIT_API_KEY env var required'); })(),
  LIVEKIT_API_SECRET: process.env.LIVEKIT_API_SECRET ?? (() => { throw new Error('LIVEKIT_API_SECRET env var required'); })(),
  LIVEKIT_URL: process.env.LIVEKIT_URL || 'wss://tele-qta84c5k.livekit.cloud',
  SUPABASE_URL: process.env.SUPABASE_URL ?? (() => { throw new Error('SUPABASE_URL env var required'); })(),
  SUPABASE_SERVICE_KEY: process.env.SUPABASE_SERVICE_KEY ?? (() => { throw new Error('SUPABASE_SERVICE_KEY env var required'); })(),
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS || '*',
};
