-- AuraCare CHAV Master Database Migration DDL
-- Database Schema for Postgres / Supabase

-- 1. Sessions Table
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('doctor', 'patient', 'guest')),
    room_id TEXT,
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked BOOLEAN DEFAULT FALSE
);

-- 2. Rooms Table
CREATE TABLE IF NOT EXISTS public.rooms (
    room_id TEXT PRIMARY KEY,
    doctor_id TEXT NOT NULL,
    ac_code TEXT NOT NULL,
    ac_attempts INT DEFAULT 0,
    ac_locked_until TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'locked', 'ended')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Biometric Captures Table
CREATE TABLE IF NOT EXISTS public.biometric_captures (
    capture_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    room_id TEXT NOT NULL,
    target_type TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Biometric Audit Logs Table
CREATE TABLE IF NOT EXISTS public.biometric_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    device_id TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verification_status TEXT NOT NULL CHECK (verification_status IN ('PASSED', 'REJECTED')),
    overall_score NUMERIC(5,2) NOT NULL,
    face_score NUMERIC(5,2) NOT NULL,
    iris_score NUMERIC(5,2) NOT NULL,
    liveness_score NUMERIC(5,2) NOT NULL,
    body_score NUMERIC(5,2) NOT NULL,
    spoof_score NUMERIC(5,2) NOT NULL,
    failure_reasons JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Doctor Availability Table
CREATE TABLE IF NOT EXISTS public.doctor_availability (
    doctor_id TEXT PRIMARY KEY,
    status TEXT NOT NULL CHECK (status IN ('online', 'offline')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for Query Performance
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_rooms_doctor_id ON public.rooms(doctor_id);
CREATE INDEX IF NOT EXISTS idx_biometric_captures_room_id ON public.biometric_captures(room_id);
CREATE INDEX IF NOT EXISTS idx_biometric_audit_logs_session_id ON public.biometric_audit_logs(session_id);
