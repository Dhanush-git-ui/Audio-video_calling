import { z } from 'zod';

export const faceScoreSchema = z.object({
  body: z.object({
    faceCount: z.number().min(0),
    ipdRatio: z.number(),
    luminance: z.number(),
    blurVariance: z.number(),
    hasMask: z.boolean().optional(),
    hasSunglasses: z.boolean().optional(),
  }),
});

export const irisScoreSchema = z.object({
  body: z.object({
    leftIrisDetected: z.boolean(),
    rightIrisDetected: z.boolean(),
    gazeAccuracyRatio: z.number().min(0).max(1),
    darkPixelCount: z.number(),
  }),
});

export const bodyScoreSchema = z.object({
  body: z.object({
    skeletonPointsCount: z.number(),
    shoulderSlope: z.number(),
    singlePersonPresent: z.boolean(),
  }),
});

export const livenessScoreSchema = z.object({
  body: z.object({
    challengesCompleted: z.number(),
    totalChallenges: z.number(),
    durationSeconds: z.number(),
  }),
});

export const antiSpoofScoreSchema = z.object({
  body: z.object({
    skinHemoglobinValid: z.boolean(),
    isRealCameraHardware: z.boolean(),
    moirePatternDetected: z.boolean().optional(),
  }),
});

export const finalizeScoreSchema = z.object({
  body: z.object({
    userId: z.string().min(1),
    roomId: z.string().min(1),
    deviceId: z.string().optional(),
    faceSignals: z.object({
      faceCount: z.number(),
      ipdRatio: z.number(),
      luminance: z.number(),
      blurVariance: z.number(),
    }).optional(),
    subScores: z.object({
      face: z.number().min(0).max(1).optional(),
      iris: z.number().min(0).max(1).optional(),
      liveness: z.number().min(0).max(1).optional(),
      body: z.number().min(0).max(1).optional(),
      antiSpoof: z.number().min(0).max(1).optional(),
    }).optional(),
  }),
});
