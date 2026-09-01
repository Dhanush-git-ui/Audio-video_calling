import { Router } from 'express';
import { validateRequest } from '../../middleware/validate.middleware.js';
import { authRateLimiter, guestVerifyRateLimiter } from '../../middleware/rateLimiter.middleware.js';
import { doctorLoginSchema, patientLoginSchema, guestVerifySchema } from './auth.schema.js';
import { doctorLoginHandler, patientLoginHandler, guestVerifyHandler, logoutHandler } from './auth.controller.js';
import { authenticateJwt } from '../../middleware/auth.middleware.js';

const router = Router();

router.post('/doctor/login', authRateLimiter, validateRequest(doctorLoginSchema), doctorLoginHandler);
router.post('/patient/login', authRateLimiter, validateRequest(patientLoginSchema), patientLoginHandler);
router.post('/guest/verify', guestVerifyRateLimiter, validateRequest(guestVerifySchema), guestVerifyHandler);
router.post('/logout', authenticateJwt, logoutHandler);

export default router;
