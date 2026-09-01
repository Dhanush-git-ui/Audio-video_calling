import { createClient } from '@supabase/supabase-js';
import { ENV } from '../../config/env.js';

export interface BiometricAuditRecord {
  id: string;
  userId: string;
  roomId: string;
  deviceId: string;
  stageScores: Record<string, number>;
  overallScore: number;
  passed: boolean;
  failureReasons: string[];
  createdAt: Date;
}

export interface BiometricCaptureRecord {
  captureId: string;
  userId: string;
  roomId: string;
  targetType: string;
  storagePath: string;
  signedUrl: string;
  createdAt: Date;
}

class BiometricService {
  private supabase;
  private memoryCaptures = new Map<string, BiometricCaptureRecord>();
  private memoryAuditLogs: BiometricAuditRecord[] = [];

  constructor() {
    this.supabase = createClient(ENV.SUPABASE_URL, ENV.SUPABASE_SERVICE_KEY);
  }

  async storeCapture(userId: string, roomId: string, targetType: string, imageDataUrl: string): Promise<BiometricCaptureRecord> {
    const captureId = `cap_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const storagePath = `biometric_captures/${roomId}/${userId}_${targetType}_${captureId}.png`;

    let signedUrl = imageDataUrl; // Fallback inline Data URL

    try {
      const base64Data = imageDataUrl.replace(/^data:image\/\w+;base64,/, '');
      const buffer = Buffer.from(base64Data, 'base64');

      const { data, error } = await this.supabase.storage
        .from('chav')
        .upload(storagePath, buffer, {
          contentType: 'image/png',
          upsert: true,
        });

      if (!error && data) {
        const { data: signedData } = await this.supabase.storage
          .from('chav')
          .createSignedUrl(storagePath, 3600); // 1 hour signed URL

        if (signedData?.signedUrl) {
          signedUrl = signedData.signedUrl;
        }
      }
    } catch (e) {
      // Inline data URL fallback
    }

    const captureRecord: BiometricCaptureRecord = {
      captureId,
      userId,
      roomId,
      targetType,
      storagePath,
      signedUrl,
      createdAt: new Date(),
    };

    this.memoryCaptures.set(captureId, captureRecord);
    return captureRecord;
  }

  async writeAuditRecord(record: Omit<BiometricAuditRecord, 'id' | 'createdAt'>): Promise<BiometricAuditRecord> {
    const auditRecord: BiometricAuditRecord = {
      ...record,
      id: `audit_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      createdAt: new Date(),
    };

    try {
      await this.supabase.from('biometric_audit_logs').insert([
        {
          user_id: auditRecord.userId,
          session_id: auditRecord.roomId,
          device_id: auditRecord.deviceId,
          timestamp: auditRecord.createdAt.toISOString(),
          verification_status: auditRecord.passed ? 'PASSED' : 'REJECTED',
          overall_score: auditRecord.overallScore,
          face_score: auditRecord.stageScores.face || 0,
          iris_score: auditRecord.stageScores.iris || 0,
          liveness_score: auditRecord.stageScores.liveness || 0,
          body_score: auditRecord.stageScores.body || 0,
          spoof_score: auditRecord.stageScores.antiSpoof || 0,
          failure_reasons: auditRecord.failureReasons,
        },
      ]);
    } catch (e) {
      // In-memory fallback
    }

    this.memoryAuditLogs.push(auditRecord);
    return auditRecord;
  }

  async getAuditTrailByRoom(roomId: string): Promise<BiometricAuditRecord[]> {
    return this.memoryAuditLogs.filter((log) => log.roomId === roomId);
  }

  async getCaptureById(captureId: string): Promise<BiometricCaptureRecord | null> {
    return this.memoryCaptures.get(captureId) || null;
  }
}

export const biometricService = new BiometricService();
