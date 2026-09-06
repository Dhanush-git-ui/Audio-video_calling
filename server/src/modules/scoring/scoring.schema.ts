import { z } from 'zod';
export const faceScoreSchema = z.object({ body: z.object({ faceCount: z.number().min(0), ipdRatio: z.number(), luminance: z.number(), blurVariance: z.number(), hasMask: z.boolean().optional(), hasSunglasses: z.boolean().optional() }) });
