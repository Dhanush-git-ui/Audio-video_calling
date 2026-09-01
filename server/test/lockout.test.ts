import assert from 'node:assert';
import test from 'node:test';
import { roomsService } from '../src/modules/rooms/rooms.service.js';

test('Guest Access Code Lockout Logic - 3 Failed Attempts', async () => {
  const room = await roomsService.createRoom('Dr. Test', 'lockout-test-room');
  const roomId = room.roomId;
  const correctCode = room.acCode;

  // Attempt 1: Wrong code -> Failed
  const res1 = await roomsService.verifyRoomAccessCode(roomId, '0000');
  assert.strictEqual(res1, false);

  // Attempt 2: Wrong code -> Failed
  const res2 = await roomsService.verifyRoomAccessCode(roomId, '0000');
  assert.strictEqual(res2, false);

  // Attempt 3: Wrong code -> Triggers 15-min Lockout
  const res3 = await roomsService.verifyRoomAccessCode(roomId, '0000');
  assert.strictEqual(res3, false);

  // Attempt 4: Correct code supplied while locked out -> Must still fail due to Lockout!
  const res4 = await roomsService.verifyRoomAccessCode(roomId, correctCode);
  assert.strictEqual(res4, false, 'Access must remain blocked during lockout window.');
});
