import { Response } from 'express';
import { AuthedRequest } from '../../middleware/auth.middleware.js';
import { roomsService } from './rooms.service.js';

export const createRoomHandler = async (req: AuthedRequest, res: Response) => {
  try {
    const doctorId = req.user?.userId || 'Dr. Doctor';
    const { roomName } = req.body;
    res.status(201).json({ success: true, data: roomsService.createRoom(doctorId, roomName) });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
};

export const mintTokenHandler = async (req: AuthedRequest, res: Response) => {
  try {
    const roomId = req.params.room_id;
    const identity = req.body.identity || req.user?.userId || 'Participant';
    const role = req.user?.role || 'patient';
    const token = await roomsService.mintLiveKitToken(roomId, identity, role);
    res.json({ success: true, token, roomId, identity, role });
  } catch (e: any) {
    res.status(400).json({ success: false, error: e.message });
  }
};

export const updateRoomStatusHandler = async (req: AuthedRequest, res: Response) => {
  try {
    roomsService.updateRoomStatus(req.params.room_id, req.body.status);
    res.json({ success: true, message: 'Room status updated' });
  } catch (e: any) {
    res.status(400).json({ success: false, error: e.message });
  }
};

export const getRoomMetadataHandler = async (req: AuthedRequest, res: Response) => {
  try {
    const data = roomsService.getRoomMetadata(req.params.room_id, req.user?.role || 'guest', req.user?.userId || '');
    res.json({ success: true, data });
  } catch (e: any) {
    res.status(404).json({ success: false, error: e.message });
  }
};

export const verifyAccessCodeHandler = async (req: AuthedRequest, res: Response) => {
  const isValid = roomsService.verifyRoomAccessCode(req.params.room_id, req.body.code);
  if (!isValid) return res.status(401).json({ success: false, error: 'Invalid access code or locked out' });
  res.json({ success: true, message: 'Access code verified' });
};
