import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env.js';

export interface JwtPayload {
  userId: string;
  role: 'doctor' | 'patient' | 'guest';
  roomId?: string;
}

export interface AuthedRequest extends Request {
  user?: JwtPayload;
}

export function authenticateJwt(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Missing Bearer token' });
  }
  try {
    const decoded = jwt.verify(header.split(' ')[1], ENV.JWT_SECRET) as JwtPayload;
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ success: false, error: 'Invalid or expired token' });
  }
}

export function requireRole(allowed: Array<JwtPayload['role']>) {
  return (req: AuthedRequest, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json({ success: false, error: 'Not authenticated' });
    if (!allowed.includes(req.user.role)) {
      return res.status(403).json({ success: false, error: `Forbidden: requires ${allowed.join(',')}` });
    }
    next();
  };
}
