const config = require('../config');

class BiometricService {
  constructor() {
    this.memoryCaptures = new Map();
    this.memoryAuditLogs = [];
  }

  async storeCapture(userId, roomId, targetType, imageDataUrl) {
    const captureId = `cap_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const storagePath = `biometric_captures/${roomId}/${userId}_${targetType}_${captureId}.png`;

    let signedUrl = imageDataUrl;

    try {
      const { createClient } = require('@supabase/supabase-js');
      const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_SERVICE_KEY);

      const base64Data = imageDataUrl.replace(/^data:image\/\w+;base64,/, '');
      const buffer = Buffer.from(base64Data, 'base64');

      const { data, error } = await supabase.storage
        .from('chav')
        .upload(storagePath, buffer, {
          contentType: 'image/png',
          upsert: true,
        });

      if (!error && data) {
        const { data: signedData } = await supabase.storage
          .from('chav')
          .createSignedUrl(storagePath, 3600);

        if (signedData && signedData.signedUrl) {
          signedUrl = signedData.signedUrl;
        }
      }
    } catch (e) {
      // In-memory fallback
    }

    const captureRecord = {
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

  async writeAuditRecord(record) {
    const auditRecord = {
      ...record,
      id: `audit_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      createdAt: new Date(),
    };

    try {
      const { createClient } = require('@supabase/supabase-js');
      const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_SERVICE_KEY);

      await supabase.from('biometric_audit_logs').insert([
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

  getAuditTrailByRoom(roomId) {
    return this.memoryAuditLogs.filter((log) => log.roomId === roomId);
  }

  getCaptureById(captureId) {
    return this.memoryCaptures.get(captureId) || null;
  }
}

const biometricService = new BiometricService();
module.exports = { biometricService };
