import { Request, Response } from 'express';
import { authService } from './auth.service.js';

export const doctorLoginHandler = async (req: Request, res: Response) => {
  try {
    const { username, password, otp } = req.body;
    const result = authService.loginDoctor(username, password, otp);
    res.json({ success: true, ...result });
  } catch (e: any) {
    res.status(401).json({ success: false, error: e.message || 'Login failed' });
  }
};
