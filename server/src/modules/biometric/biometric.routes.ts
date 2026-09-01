import { Router } from 'express';
import { authenticateJwt, requireRole } from '../../middleware/auth.middleware.js';
import { validateRequest } from '../../middleware/validate.middleware.js';
import { biometricCaptureSchema, biometricAuditWriteSchema } from './biometric.schema.js';
import {
  captureBiometricHandler,
  internalAuditWriteHandler,
  getAuditLogsHandler,
  getCaptureByIdHandler,
} from './biometric.controller.js';

const router = Router();

router.post('/capture', authenticateJwt, validateRequest(biometricCaptureSchema), captureBiometricHandler);
router.post('/audit', authenticateJwt, validateRequest(biometricAuditWriteSchema), internalAuditWriteHandler);
router.get('/audit/:room_id', authenticateJwt, requireRole(['doctor']), getAuditLogsHandler);
router.get('/capture/:capture_id', authenticateJwt, requireRole(['doctor']), getCaptureByIdHandler);

export default router;
