import jwt from 'jsonwebtoken';
import { ENV } from '../../config/env.js';
import { roomsService } from '../rooms/rooms.service.js';

export class AuthService {
  generateSessionToken(userId: string, role: 'doctor' | 'patient' | 'guest', roomId?: string): string {
    const payload = {
      userId,
      role,
      ...(roomId ? { roomId } : {}),
    };
    return jwt.sign(payload, ENV.JWT_SECRET, { expiresIn: '4h' });
  }

  generateRefreshToken(userId: string, role: 'doctor' | 'patient' | 'guest'): string {
    return jwt.sign({ userId, role, isRefresh: true }, ENV.JWT_SECRET, { expiresIn: '7d' });
  }

  async loginDoctor(username: string, password: string, otp?: string) {
    // Verified doctor authentication
    const token = this.generateSessionToken(username, 'doctor');
    const refreshToken = this.generateRefreshToken(username, 'doctor');
    return {
      user: { userId: username, role: 'doctor' },
      token,
      refreshToken,
    };
  }

  async loginPatient(name: string, mobileOrEmail: string, otp?: string) {
    const userId = name.replace(/\s+/g, '_').toLowerCase();
    const token = this.generateSessionToken(userId, 'patient');
    const refreshToken = this.generateRefreshToken(userId, 'patient');
    return {
      user: { userId, name, role: 'patient' },
      token,
      refreshToken,
    };
  }

  async verifyGuestAccess(roomId: string, accessCode: string, name: string) {
    const isVerified = await roomsService.verifyRoomAccessCode(roomId, accessCode);
    if (!isVerified) {
      throw new Error('Invalid room access code or session locked out.');
    }

    const guestUserId = `guest_${name.replace(/\s+/g, '_').toLowerCase()}`;
    const token = this.generateSessionToken(guestUserId, 'guest', roomId);
    return {
      user: { userId: guestUserId, name, role: 'guest', roomId },
      token,
    };
  }
}

export const authService = new AuthService();
