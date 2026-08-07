import assert from 'node:assert';
import test from 'node:test';
import { scoringService } from '../src/modules/scoring/scoring.service.js';

test('AI Scoring Engine - Math Weights & Pass Threshold', async () => {
  // Test case 1: Perfect scores -> 100% -> Passed
  const perfectResult = await scoringService.finalizeVerification({
    userId: 'test_user',
    roomId: 'test_room',
    subScores: { face: 1.0, iris: 1.0, liveness: 1.0, body: 1.0, antiSpoof: 1.0 },
  });

  assert.strictEqual(perfectResult.overallScore, 100.0);
  assert.strictEqual(perfectResult.passed, true);
  assert.strictEqual(perfectResult.failureReasons.length, 0);

  // Test case 2: Borderline score (90.0%) -> Passed
  const borderlineResult = await scoringService.finalizeVerification({
    userId: 'test_user',
    roomId: 'test_room',
    subScores: { face: 0.90, iris: 0.90, liveness: 0.90, body: 0.90, antiSpoof: 0.90 },
  });

  assert.strictEqual(borderlineResult.overallScore, 90.0);
  assert.strictEqual(borderlineResult.passed, true);

  // Test case 3: Below 90.0% (89.0%) -> Rejected
  const failResult = await scoringService.finalizeVerification({
    userId: 'test_user',
    roomId: 'test_room',
    subScores: { face: 0.89, iris: 0.89, liveness: 0.89, body: 0.89, antiSpoof: 0.89 },
  });

  assert.strictEqual(failResult.overallScore, 89.0);
  assert.strictEqual(failResult.passed, false);
  assert.ok(failResult.failureReasons.length > 0);
});
