const config = require('../config');
const { signJwt } = require('../middleware/auth');
const { roomsService } = require('./rooms');

class AuthService {
  generateSessionToken(userId, role, roomId) {
    const payload = {
      userId,
      role,
      ...(roomId ? { roomId } : {}),
    };
    return signJwt(payload, config.JWT_SECRET, 14400); // 4 hours
  }

  generateRefreshToken(userId, role) {
    return signJwt({ userId, role, isRefresh: true }, config.JWT_SECRET, 604800); // 7 days
  }

  loginDoctor(username, password, otp) {
    const token = this.generateSessionToken(username, 'doctor');
    const refreshToken = this.generateRefreshToken(username, 'doctor');
    return {
      user: { userId: username, role: 'doctor' },
      token,
      refreshToken,
    };
  }

  loginPatient(name, mobileOrEmail, otp) {
    const userId = name.replace(/\s+/g, '_').toLowerCase();
    const token = this.generateSessionToken(userId, 'patient');
    const refreshToken = this.generateRefreshToken(userId, 'patient');
    return {
      user: { userId, name, role: 'patient' },
      token,
      refreshToken,
    };
  }

  verifyGuestAccess(roomId, accessCode, name) {
    const isVerified = roomsService.verifyRoomAccessCode(roomId, accessCode);
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

const authService = new AuthService();
module.exports = { authService };
