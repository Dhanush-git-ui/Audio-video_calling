import { Router } from 'express';
import { authenticateJwt, requireRole } from '../../middleware/auth.middleware.js';
import { validateRequest } from '../../middleware/validate.middleware.js';
import { authRateLimiter, guestVerifyRateLimiter } from '../../middleware/rateLimiter.middleware.js';
import { doctorLoginSchema, patientLoginSchema, guestVerifySchema } from './auth.schema.js';

const router = Router();

router.post('/doctor/login', authRateLimiter, validateRequest(doctorLoginSchema), async (req, res) => {
  try {
    const { username, password, otp } = req.body;
    const { authService } = await import('./auth.service.js');
    const result = authService.loginDoctor(username, password, otp);
    res.json({ success: true, ...result });
  } catch (e: any) {
    res.status(401).json({ success: false, error: e.message || 'Login failed' });
  }
});

router.post('/patient/login', authRateLimiter, validateRequest(patientLoginSchema), async (req, res) => {
  try {
    const { name, mobileOrEmail, otp } = req.body;
    const { authService } = await import('./auth.service.js');
    const result = authService.loginPatient(name, mobileOrEmail, otp);
    res.json({ success: true, ...result });
  } catch (e: any) {
    res.status(401).json({ success: false, error: e.message || 'Login failed' });
  }
});

router.post('/guest/verify', guestVerifyRateLimiter, validateRequest(guestVerifySchema), async (req, res) => {
  try {
    const { roomId, accessCode, name } = req.body;
    const { authService } = await import('./auth.service.js');
    const result = await authService.verifyGuestAccess(roomId, accessCode, name);
    res.json({ success: true, ...result });
  } catch (e: any) {
    res.status(401).json({ success: false, error: e.message || 'Guest verification failed' });
  }
});

router.post('/logout', authenticateJwt, (_req, res) => {
  res.json({ success: true, message: 'Logged out' });
});

export default router;
