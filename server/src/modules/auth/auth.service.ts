import jwt from 'jsonwebtoken';
import { ENV } from '../../config/env.js';

export class AuthService {
  generateSessionToken(userId: string, role: 'doctor' | 'patient' | 'guest', roomId?: string) {
    return jwt.sign({ userId, role, ...(roomId ? { roomId } : {}) }, ENV.JWT_SECRET, { expiresIn: '4h' });
  }
  generateRefreshToken(userId: string, role: 'doctor' | 'patient' | 'guest') {
    return jwt.sign({ userId, role, isRefresh: true }, ENV.JWT_SECRET, { expiresIn: '7d' });
  }
  loginDoctor(username: string, _password?: string, _otp?: string) {
    const token = this.generateSessionToken(username, 'doctor');
    const refreshToken = this.generateRefreshToken(username, 'doctor');
    return { user: { userId: username, role: 'doctor' as const }, token, refreshToken };
  }
  loginPatient(name: string, mobileOrEmail?: string, _otp?: string) {
    const userId = name.replace(/\s+/g, '_').toLowerCase();
    const token = this.generateSessionToken(userId, 'patient');
    const refreshToken = this.generateRefreshToken(userId, 'patient');
    return { user: { userId, name, role: 'patient' as const }, token, refreshToken };
  }
  async verifyGuestAccess(roomId: string, accessCode: string, name: string) {
    // Access code verification delegated to RoomsService
    // Placeholder: call roomsService.verifyRoomAccessCode in real integration
    const isValid = accessCode === '1111'; // placeholder
    if (!isValid) throw new Error('Invalid room access code');
    const userId = `guest_${name.replace(/\s+/g, '_').toLowerCase()}`;
    const token = this.generateSessionToken(userId, 'guest', roomId);
    return { user: { userId, name, role: 'guest' as const, roomId }, token };
  }
}
export const authService = new AuthService();
