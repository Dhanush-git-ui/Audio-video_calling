import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware.js';
import { roomsService } from './rooms.service.js';

export const createRoomHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const doctorId = req.user?.userId || 'Dr. Doctor';
    const { roomName } = req.body;
    const result = await roomsService.createRoom(doctorId, roomName);
    return res.status(201).json({ success: true, data: result });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message || 'Failed to create room' });
  }
};

export const mintTokenHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const roomId = req.params.room_id;
    const identity = req.body.identity || req.user?.userId || 'Participant';
    const role = req.user?.role || 'patient';

    const token = await roomsService.mintLiveKitToken(roomId, identity, role);
    return res.json({ success: true, token, roomId, identity, role });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message || 'Token generation failed' });
  }
};

export const updateRoomStatusHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const roomId = req.params.room_id;
    const { status } = req.body;
    await roomsService.updateRoomStatus(roomId, status);
    return res.json({ success: true, message: `Room status updated to '${status}'.` });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message || 'Failed to update status' });
  }
};

export const getRoomMetadataHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const roomId = req.params.room_id;
    const requesterRole = req.user?.role || 'guest';
    const requesterId = req.user?.userId || '';

    const metadata = await roomsService.getRoomMetadata(roomId, requesterRole, requesterId);
    return res.json({ success: true, data: metadata });
  } catch (err: any) {
    return res.status(404).json({ success: false, error: err.message || 'Room metadata unavailable' });
  }
};

export const verifyAccessCodeHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const roomId = req.params.room_id;
    const { code } = req.body;

    const isValid = await roomsService.verifyRoomAccessCode(roomId, code);
    if (!isValid) {
      return res.status(401).json({ success: false, error: 'Invalid room access code.' });
    }
    return res.json({ success: true, message: 'Access code verified successfully.' });
  } catch (err: any) {
    return res.status(401).json({ success: false, error: 'Invalid room access code.' });
  }
};
