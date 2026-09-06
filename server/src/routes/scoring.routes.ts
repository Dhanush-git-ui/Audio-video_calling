import { Router } from 'express';
import { scoringService } from '../modules/scoring/scoring.service.js';
const router = Router();
router.post('/face', (req, res) => res.json({ success: true, ...scoringService.calculateFaceScore(req.body) }));
router.post('/finalize', async (req, res) => { const result = await scoringService.finalizeVerification(req.body); res.json({ success: true, ...result }); });
export default router;
