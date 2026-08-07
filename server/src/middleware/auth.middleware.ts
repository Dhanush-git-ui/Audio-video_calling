import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env.js';

export interface JwtPayload {
  userId: string;
  role: 'doctor' | 'patient' | 'guest';
  roomId?: string;
  iat?: number;
  exp?: number;
}

export interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}

export const authenticateJwt = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Missing or malformed Bearer token.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, ENV.JWT_SECRET) as JwtPayload;
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Invalid or expired session token.' });
  }
};

export const requireRole = (allowedRoles: Array<'doctor' | 'patient' | 'guest'>) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'Unauthorized: User identity not verified.' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: `Forbidden: Insufficient privileges for role '${req.user.role}'. Required: ${allowedRoles.join(', ')}`,
      });
    }

    // Room-scoped security check for guest role
    if (req.user.role === 'guest') {
      const targetRoom = req.params.room_id || req.body.room_id || req.query.room_id;
      if (targetRoom && req.user.roomId && req.user.roomId !== targetRoom) {
        return res.status(403).json({
          success: false,
          error: `Forbidden: Guest token for room '${req.user.roomId}' cannot access room '${targetRoom}'.`,
        });
      }
    }

    next();
  };
};
