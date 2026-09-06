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

-- ============================================================================
-- 6. Supabase Storage Bucket Configuration: chav_consultation_files
-- Organization: Shalini_Org (Free plan) | Project: CHAV (PRODUCTION)
-- Target Bucket: chav_consultation_files (Public bucket)
-- Folder: consultation-files/
-- ============================================================================

-- Create public bucket chav_consultation_files if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chav_consultation_files',
    'chav_consultation_files',
    true,
    52428800, -- 50MB file size limit
    NULL      -- Allow all consultation file types
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage Security Policies for chav_consultation_files
-- 1. Allow public and anonymous read access to consultation files
DROP POLICY IF EXISTS "Allow Public Read Consultation Files" ON storage.objects;
CREATE POLICY "Allow Public Read Consultation Files"
ON storage.objects FOR SELECT
TO anon, authenticated, service_role
USING (bucket_id = 'chav_consultation_files');

-- 2. Allow anonymous and authenticated users to upload to chav_consultation_files
DROP POLICY IF EXISTS "Allow Upload Consultation Files" ON storage.objects;
CREATE POLICY "Allow Upload Consultation Files"
ON storage.objects FOR INSERT
TO anon, authenticated, service_role
WITH CHECK (
    bucket_id = 'chav_consultation_files'
);

-- 3. Allow updates / upserts in chav_consultation_files
DROP POLICY IF EXISTS "Allow Update Consultation Files" ON storage.objects;
CREATE POLICY "Allow Update Consultation Files"
ON storage.objects FOR UPDATE
TO anon, authenticated, service_role
USING (bucket_id = 'chav_consultation_files')
WITH CHECK (bucket_id = 'chav_consultation_files');

-- 4. Allow deletion for automated retention cleanup and authorized services
DROP POLICY IF EXISTS "Allow Retention Delete Consultation Files" ON storage.objects;
CREATE POLICY "Allow Retention Delete Consultation Files"
ON storage.objects FOR DELETE
TO anon, authenticated, service_role
USING (bucket_id = 'chav_consultation_files');

-- ============================================================================
-- 7. 20-Day Automated Deletion / Retention Policy
-- Ensures every file uploaded to chav_consultation_files under consultation-files/
-- is automatically deleted exactly 20 days after its upload timestamp.
-- ============================================================================

-- Stored function to purge files older than 20 days
CREATE OR REPLACE FUNCTION public.delete_expired_consultation_files()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INT;
BEGIN
    WITH deleted_rows AS (
        DELETE FROM storage.objects
        WHERE bucket_id = 'chav_consultation_files'
          AND name LIKE 'consultation-files/%'
          AND created_at < (NOW() - INTERVAL '20 days')
        RETURNING id
    )
    SELECT count(*) INTO deleted_count FROM deleted_rows;

    RETURN jsonb_build_object(
        'status', 'success',
        'deleted_files_count', deleted_count,
        'executed_at', NOW()
    );
END;
$$;

-- Enable pg_cron extension if not already active
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule automated daily retention cleanup at 00:00 UTC (every 24 hours)
-- Any file uploaded >= 20 days ago will be automatically deleted permanently
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Unschedule existing job if already scheduled
        PERFORM cron.unschedule('delete-expired-consultation-files-job')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'delete-expired-consultation-files-job');

        -- Schedule job to execute daily at midnight
        PERFORM cron.schedule(
            'delete-expired-consultation-files-job',
            '0 0 * * *',
            'SELECT public.delete_expired_consultation_files();'
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron scheduling notice: %', SQLERRM;
END $$;
