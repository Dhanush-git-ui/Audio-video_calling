import { z } from 'zod';

export const biometricCaptureSchema = z.object({
  body: z.object({
    roomId: z.string().min(1, 'Room ID is required'),
    targetType: z.enum(['both_eyes', 'left_eye', 'right_eye', 'face', 'body', 'BothEyes', 'LeftEye', 'RightEye', 'Face', 'Body']),
    imageDataUrl: z.string().min(10, 'Base64 image data is required'),
  }),
});

export const biometricAuditWriteSchema = z.object({
  body: z.object({
    userId: z.string().min(1),
    roomId: z.string().min(1),
    deviceId: z.string().optional(),
    stageScores: z.record(z.number()),
    overallScore: z.number(),
    passed: z.boolean(),
    failureReasons: z.array(z.string()).optional(),
  }),
});
