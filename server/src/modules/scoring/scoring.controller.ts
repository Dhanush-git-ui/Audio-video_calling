import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware.js';
import { scoringService } from './scoring.service.js';

export const faceScoreHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = scoringService.calculateFaceScore(req.body);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const irisScoreHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = scoringService.calculateIrisScore(req.body);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const bodyScoreHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = scoringService.calculateBodyScore(req.body);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const livenessScoreHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = scoringService.calculateLivenessScore(req.body);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const antiSpoofScoreHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = scoringService.calculateAntiSpoofScore(req.body);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const finalizeScoreHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { userId, roomId, deviceId, faceSignals, subScores } = req.body;
    let computedSubScores = subScores || {};

    if (faceSignals) {
      const faceRes = scoringService.calculateFaceScore(faceSignals);
      computedSubScores.face = faceRes.score;
    }

    const result = await scoringService.finalizeVerification({
      userId,
      roomId,
      deviceId,
      subScores: computedSubScores,
    });

    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message || 'Verification finalization failed' });
  }
};
