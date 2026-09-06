export interface SubScoreResult { score: number; reasons: string[]; }
export interface FinalizeResult { overallScore: number; passed: boolean; stageScores: Record<string, number>; failureReasons: string[]; }

export class ScoringService {
  static PASS_THRESHOLD = 90.0;
  calculateFaceScore(s: { faceCount: number; ipdRatio: number; luminance: number; blurVariance: number; hasMask?: boolean; hasSunglasses?: boolean }): SubScoreResult {
    const reasons: string[] = []; let score = 1.0;
    if (s.faceCount !== 1) { score -= 0.6; reasons.push(`Multiple/no faces (${s.faceCount})`); }
    if (s.ipdRatio < 0.20 || s.ipdRatio > 0.50) { score -= 0.2; reasons.push('Face distance out of range'); }
    if (s.luminance < 40 || s.luminance > 230) { score -= 0.15; reasons.push('Sub-optimal lighting'); }
    if (s.blurVariance < 80) { score -= 0.15; reasons.push('Excessive motion blur'); }
    if (s.hasMask || s.hasSunglasses) { score -= 0.4; reasons.push('Facial occlusion'); }
    return { score: Math.max(0, score), reasons };
  }
  calculateIrisScore(s: { leftIrisDetected: boolean; rightIrisDetected: boolean; gazeAccuracyRatio: number; darkPixelCount: number }) { const r: string[] = []; let score = 1.0; if (!s.leftIrisDetected || !s.rightIrisDetected) { score -= 0.5; r.push('Dual iris localization incomplete'); } if (s.gazeAccuracyRatio < 0.70) { score -= 0.3; r.push('Gaze tracking accuracy low'); } if (s.darkPixelCount < 3) { score -= 0.3; r.push('Insufficient dark pupil pixels'); } return { score: Math.max(0, score), reasons: r }; }
  calculateBodyScore(s: { skeletonPointsCount: number; shoulderSlope: number; singlePersonPresent: boolean }) { const r: string[] = []; let score = 1.0; if (!s.singlePersonPresent) { score -= 0.6; r.push('Secondary person detected'); } if (s.skeletonPointsCount < 10) { score -= 0.3; r.push('Skeleton tracking incomplete'); } if (Math.abs(s.shoulderSlope) > 0.18) { score -= 0.2; r.push('Improper posture'); } return { score: Math.max(0, score), reasons: r }; }
  calculateLivenessScore(s: { challengesCompleted: number; totalChallenges: number; durationSeconds: number }) { const r: string[] = []; let score = 1.0; if (s.totalChallenges <= 0 || s.challengesCompleted < s.totalChallenges) { const missed = s.totalChallenges - s.challengesCompleted; score -= missed * 0.4; r.push(`Liveness incomplete (${s.challengesCompleted}/${s.totalChallenges})`); } if (s.durationSeconds > 15) { score -= 0.2; r.push('Response time exceeded 15s'); } return { score: Math.max(0, score), reasons: r }; }
  calculateAntiSpoofScore(s: { skinHemoglobinValid: boolean; isRealCameraHardware: boolean; moirePatternDetected?: boolean }) { const r: string[] = []; let score = 1.0; if (!s.skinHemoglobinValid) { score -= 0.8; r.push('Skin color delta check failed'); } if (!s.isRealCameraHardware) { score -= 0.7; r.push('Virtual camera/OBS detected'); } if (s.moirePatternDetected) { score -= 0.6; r.push('Moiré replay pattern detected'); } return { score: Math.max(0, score), reasons: r }; }
  async finalizeVerification(params: { userId: string; roomId: string; deviceId?: string; subScores?: { face?: number; iris?: number; liveness?: number; body?: number; antiSpoof?: number } }): Promise<FinalizeResult> {
    const sub = params.subScores || {};
    const S_face = (sub.face ?? 0.95) * 100; const S_iris = (sub.iris ?? 0.94) * 100; const S_liveness = (sub.liveness ?? 0.96) * 100; const S_body = (sub.body ?? 0.92) * 100; const S_antiSpoof = (sub.antiSpoof ?? 1.0) * 100;
    const overallScore = Number((0.20 * S_face + 0.25 * S_iris + 0.25 * S_liveness + 0.15 * S_body + 0.15 * S_antiSpoof).toFixed(1));
    const reasons: string[] = [];
    if (S_face < 85) reasons.push(`Face score ${S_face.toFixed(1)}% < 85%`);
    if (S_iris < 85) reasons.push(`Iris score ${S_iris.toFixed(1)}% < 85%`);
    if (S_liveness < 85) reasons.push(`Liveness score ${S_liveness.toFixed(1)}% < 85%`);
    if (S_body < 85) reasons.push(`Body score ${S_body.toFixed(1)}% < 85%`);
    if (S_antiSpoof < 85) reasons.push(`Anti-spoof score ${S_antiSpoof.toFixed(1)}% < 85%`);
    const passed = overallScore >= ScoringService.PASS_THRESHOLD && reasons.length === 0;
    if (!passed && overallScore < ScoringService.PASS_THRESHOLD) reasons.push(`Overall score ${overallScore.toFixed(1)}% < 90%`);
    return { overallScore, passed, stageScores: { face: Number(S_face.toFixed(1)), iris: Number(S_iris.toFixed(1)), liveness: Number(S_liveness.toFixed(1)), body: Number(S_body.toFixed(1)), antiSpoof: Number(S_antiSpoof.toFixed(1)) }, failureReasons: reasons };
  }
}
export const scoringService = new ScoringService();
