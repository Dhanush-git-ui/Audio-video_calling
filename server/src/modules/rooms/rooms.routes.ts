import { Router } from 'express';
import { authenticateJwt, requireRole } from '../../middleware/auth.middleware.js';
import { validateRequest } from '../../middleware/validate.middleware.js';
import { guestVerifyRateLimiter } from '../../middleware/rateLimiter.middleware.js';
import { createRoomSchema, mintTokenSchema, updateRoomStatusSchema, verifyCodeSchema } from './rooms.schema.js';
import { createRoomHandler, mintTokenHandler, updateRoomStatusHandler, getRoomMetadataHandler, verifyAccessCodeHandler } from './rooms.controller.js';

const router = Router();
router.post('/', authenticateJwt, requireRole(['doctor']), validateRequest(createRoomSchema), createRoomHandler);
router.post('/:room_id/token', authenticateJwt, validateRequest(mintTokenSchema), mintTokenHandler);
router.patch('/:room_id/status', authenticateJwt, requireRole(['doctor']), validateRequest(updateRoomStatusSchema), updateRoomStatusHandler);
router.get('/:room_id', authenticateJwt, getRoomMetadataHandler);
router.post('/:room_id/verify-code', guestVerifyRateLimiter, validateRequest(verifyCodeSchema), verifyAccessCodeHandler);
export default router;
