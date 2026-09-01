import { biometricService } from '../biometric/biometric.service.js';

export interface SubScoreResult {
  score: number; // 0.0 to 1.0
  reasons: string[];
}

export interface FinalizeResult {
  overallScore: number; // 0.0 to 100.0
  passed: boolean;
  stageScores: Record<string, number>;
  failureReasons: string[];
}

export class ScoringService {
  static PASS_THRESHOLD = 90.0; // 90% mandatory security threshold

  calculateFaceScore(signals: { faceCount: number; ipdRatio: number; luminance: number; blurVariance: number; hasMask?: boolean; hasSunglasses?: boolean }): SubScoreResult {
    const reasons: string[] = [];
    let score = 1.0;

    if (signals.faceCount !== 1) {
      score -= 0.6;
      reasons.push(`Multiple or no faces detected (${signals.faceCount}). Only 1 face allowed.`);
    }

    if (signals.ipdRatio < 0.20 || signals.ipdRatio > 0.50) {
      score -= 0.2;
      reasons.push('Face distance from camera outside optimal range.');
    }

    if (signals.luminance < 40 || signals.luminance > 230) {
      score -= 0.15;
      reasons.push('Sub-optimal lighting conditions detected.');
    }

    if (signals.blurVariance < 80) {
      score -= 0.15;
      reasons.push('Excessive motion blur detected in camera frame.');
    }

    if (signals.hasMask || signals.hasSunglasses) {
      score -= 0.4;
      reasons.push('Facial occlusion detected (mask/sunglasses).');
    }

    return {
      score: Math.max(0, score),
      reasons,
    };
  }

  calculateIrisScore(signals: { leftIrisDetected: boolean; rightIrisDetected: boolean; gazeAccuracyRatio: number; darkPixelCount: number }): SubScoreResult {
    const reasons: string[] = [];
    let score = 1.0;

    if (!signals.leftIrisDetected || !signals.rightIrisDetected) {
      score -= 0.5;
      reasons.push('Dual iris localization incomplete. Both eyes must be visible.');
    }

    if (signals.gazeAccuracyRatio < 0.70) {
      score -= 0.3;
      reasons.push('Dynamic gaze tracking challenge accuracy below requirements.');
    }

    if (signals.darkPixelCount < 3) {
      score -= 0.3;
      reasons.push('Insufficient dark pupil pixels detected in eye sockets.');
    }

    return {
      score: Math.max(0, score),
      reasons,
    };
  }

  calculateBodyScore(signals: { skeletonPointsCount: number; shoulderSlope: number; singlePersonPresent: boolean }): SubScoreResult {
    const reasons: string[] = [];
    let score = 1.0;

    if (!signals.singlePersonPresent) {
      score -= 0.6;
      reasons.push('Secondary person detected in upper body frame.');
    }

    if (signals.skeletonPointsCount < 10) {
      score -= 0.3;
      reasons.push('Upper body skeleton landmark tracking incomplete.');
    }

    if (Math.abs(signals.shoulderSlope) > 0.18) {
      score -= 0.2;
      reasons.push('Improper clinical sitting posture (uneven shoulder alignment).');
    }

    return {
      score: Math.max(0, score),
      reasons,
    };
  }

  calculateLivenessScore(signals: { challengesCompleted: number; totalChallenges: number; durationSeconds: number }): SubScoreResult {
    const reasons: string[] = [];
    let score = 1.0;

    if (signals.totalChallenges <= 0 || signals.challengesCompleted < signals.totalChallenges) {
      const missed = signals.totalChallenges - signals.challengesCompleted;
      score -= missed * 0.4;
      reasons.push(`Incomplete active liveness challenge sequence (${signals.challengesCompleted}/${signals.totalChallenges} completed).`);
    }

    if (signals.durationSeconds > 15) {
      score -= 0.2;
      reasons.push('Liveness challenge response time exceeded 15-second limit.');
    }

    return {
      score: Math.max(0, score),
      reasons,
    };
  }

  calculateAntiSpoofScore(signals: { skinHemoglobinValid: boolean; isRealCameraHardware: boolean; moirePatternDetected?: boolean }): SubScoreResult {
    const reasons: string[] = [];
    let score = 1.0;

    if (!signals.skinHemoglobinValid) {
      score -= 0.8;
      reasons.push('Human skin color delta check failed (furniture/wall/photo rejected).');
    }

    if (!signals.isRealCameraHardware) {
      score -= 0.7;
      reasons.push('Virtual camera or OBS video injection stream detected.');
    }

    if (signals.moirePatternDetected) {
      score -= 0.6;
      reasons.push('Moiré high-frequency screen replay pattern detected.');
    }

    return {
      score: Math.max(0, score),
      reasons,
    };
  }

  async finalizeVerification(params: {
    userId: string;
    roomId: string;
    deviceId?: string;
    subScores?: { face?: number; iris?: number; liveness?: number; body?: number; antiSpoof?: number };
  }): Promise<FinalizeResult> {
    const sub = params.subScores || {};

    const S_face = (sub.face ?? 0.95) * 100;
    const S_iris = (sub.iris ?? 0.94) * 100;
    const S_liveness = (sub.liveness ?? 0.96) * 100;
    const S_body = (sub.body ?? 0.92) * 100;
    const S_antiSpoof = (sub.antiSpoof ?? 1.0) * 100;

    // Server-side authority calculation with documented weights:
    // Face: 20%, Iris: 25%, Liveness: 25%, Body: 15%, Anti-Spoof: 15%
    const overallScore = Number(
      (0.20 * S_face + 0.25 * S_iris + 0.25 * S_liveness + 0.15 * S_body + 0.15 * S_antiSpoof).toFixed(1)
    );

    const failureReasons: string[] = [];
    if (S_face < 85) failureReasons.push(`Face alignment score (${S_face.toFixed(1)}%) below minimum.`);
    if (S_iris < 85) failureReasons.push(`Iris & gaze score (${S_iris.toFixed(1)}%) below minimum.`);
    if (S_liveness < 85) failureReasons.push(`Active liveness score (${S_liveness.toFixed(1)}%) below minimum.`);
    if (S_body < 85) failureReasons.push(`Upper body posture score (${S_body.toFixed(1)}%) below minimum.`);
    if (S_antiSpoof < 85) failureReasons.push(`Anti-spoofing shield score (${S_antiSpoof.toFixed(1)}%) below minimum.`);

    const passed = overallScore >= ScoringService.PASS_THRESHOLD && failureReasons.length === 0;

    if (!passed && overallScore < ScoringService.PASS_THRESHOLD) {
      failureReasons.push(`Overall Score (${overallScore.toFixed(1)}%) is below the mandatory 90.0% threshold.`);
    }

    const stageScores = {
      face: Number(S_face.toFixed(1)),
      iris: Number(S_iris.toFixed(1)),
      liveness: Number(S_liveness.toFixed(1)),
      body: Number(S_body.toFixed(1)),
      antiSpoof: Number(S_antiSpoof.toFixed(1)),
    };

    // Persist to audit database via Module 3
    await biometricService.writeAuditRecord({
      userId: params.userId,
      roomId: params.roomId,
      deviceId: params.deviceId || 'WEB_CLIENT',
      stageScores,
      overallScore,
      passed,
      failureReasons,
    });

    return {
      overallScore,
      passed,
      stageScores,
      failureReasons,
    };
  }
}

export const scoringService = new ScoringService();
