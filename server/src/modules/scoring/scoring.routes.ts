import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware.js';
import { validateRequest } from '../../middleware/validate.middleware.js';
import {
  faceScoreSchema,
  irisScoreSchema,
  bodyScoreSchema,
  livenessScoreSchema,
  antiSpoofScoreSchema,
  finalizeScoreSchema,
} from './scoring.schema.js';
import {
  faceScoreHandler,
  irisScoreHandler,
  bodyScoreHandler,
  livenessScoreHandler,
  antiSpoofScoreHandler,
  finalizeScoreHandler,
} from './scoring.controller.js';

const router = Router();

router.post('/face', authenticateJwt, validateRequest(faceScoreSchema), faceScoreHandler);
router.post('/iris', authenticateJwt, validateRequest(irisScoreSchema), irisScoreHandler);
router.post('/body', authenticateJwt, validateRequest(bodyScoreSchema), bodyScoreHandler);
router.post('/liveness', authenticateJwt, validateRequest(livenessScoreSchema), livenessScoreHandler);
router.post('/anti-spoof', authenticateJwt, validateRequest(antiSpoofScoreSchema), antiSpoofScoreHandler);
router.post('/finalize', authenticateJwt, validateRequest(finalizeScoreSchema), finalizeScoreHandler);

export default router;
