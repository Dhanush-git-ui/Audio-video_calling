import { z } from 'zod';

export const doctorLoginSchema = z.object({
  body: z.object({
    username: z.string().min(1, 'Username is required'),
    password: z.string().min(4, 'Password must be at least 4 characters'),
    otp: z.string().optional(),
  }),
});

export const patientLoginSchema = z.object({
  body: z.object({
    name: z.string().min(1, 'Patient name is required'),
    mobileOrEmail: z.string().min(1, 'Mobile or Email is required'),
    otp: z.string().optional(),
  }),
});

export const guestVerifySchema = z.object({
  body: z.object({
    roomId: z.string().min(1, 'Room ID is required'),
    accessCode: z.string().length(4, 'Access Code must be exactly 4 digits'),
    name: z.string().min(1, 'Guest name is required'),
  }),
});

export const refreshTokenSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1, 'Refresh token is required'),
  }),
});
