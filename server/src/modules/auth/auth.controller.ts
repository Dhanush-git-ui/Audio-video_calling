import { Request, Response } from 'express';
import { authService } from './auth.service.js';

export const doctorLoginHandler = async (req: Request, res: Response) => {
  try {
    const { username, password, otp } = req.body;
    const result = await authService.loginDoctor(username, password, otp);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(401).json({ success: false, error: err.message || 'Authentication failed' });
  }
};

export const patientLoginHandler = async (req: Request, res: Response) => {
  try {
    const { name, mobileOrEmail, otp } = req.body;
    const result = await authService.loginPatient(name, mobileOrEmail, otp);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(401).json({ success: false, error: err.message || 'Authentication failed' });
  }
};

export const guestVerifyHandler = async (req: Request, res: Response) => {
  try {
    const { roomId, accessCode, name } = req.body;
    const result = await authService.verifyGuestAccess(roomId, accessCode, name);
    return res.json({ success: true, ...result });
  } catch (err: any) {
    return res.status(401).json({ success: false, error: err.message || 'Invalid room access code.' });
  }
};

export const logoutHandler = async (req: Request, res: Response) => {
  return res.json({ success: true, message: 'Session logged out successfully.' });
};
