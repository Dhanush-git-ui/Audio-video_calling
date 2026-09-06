import { z } from 'zod';

export const doctorLoginSchema = z.object({ body: z.object({ username: z.string().min(1), password: z.string().min(4), otp: z.string().optional() }) });
export const patientLoginSchema = z.object({ body: z.object({ name: z.string().min(1), mobileOrEmail: z.string().min(1), otp: z.string().optional() }) });
export const guestVerifySchema = z.object({ body: z.object({ roomId: z.string().min(1), accessCode: z.string().length(4), name: z.string().min(1) }) });
