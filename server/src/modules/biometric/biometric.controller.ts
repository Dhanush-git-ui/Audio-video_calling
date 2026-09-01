import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware.js';
import { biometricService } from './biometric.service.js';

export const captureBiometricHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.userId || 'patient_user';
    const { roomId, targetType, imageDataUrl } = req.body;

    const result = await biometricService.storeCapture(userId, roomId, targetType, imageDataUrl);
    return res.status(201).json({ success: true, data: result });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message || 'Capture upload failed' });
  }
};

export const internalAuditWriteHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { userId, roomId, deviceId, stageScores, overallScore, passed, failureReasons } = req.body;
    const record = await biometricService.writeAuditRecord({
      userId,
      roomId,
      deviceId: deviceId || 'INTERNAL_SERVER',
      stageScores,
      overallScore,
      passed,
      failureReasons: failureReasons || [],
    });
    return res.status(201).json({ success: true, data: record });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message || 'Audit write failed' });
  }
};

export const getAuditLogsHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const roomId = req.params.room_id;
    const logs = await biometricService.getAuditTrailByRoom(roomId);
    return res.json({ success: true, data: logs });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message || 'Failed to fetch audit logs' });
  }
};

export const getCaptureByIdHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const captureId = req.params.capture_id;
    const capture = await biometricService.getCaptureById(captureId);
    if (!capture) {
      return res.status(404).json({ success: false, error: 'Capture record not found.' });
    }
    return res.json({ success: true, data: capture });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message || 'Failed to fetch capture' });
  }
};
