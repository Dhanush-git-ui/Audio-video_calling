const config = require('../config');
const { signJwt } = require('../middleware/auth');

class RoomsService {
  constructor() {
    this.roomsMap = new Map();
    this.roomsMap.set('my-consultation-room', {
      roomId: 'my-consultation-room',
      doctorId: 'Dr. Amanulla Belg',
      acCode: '1111',
      acAttempts: 0,
      acLockedUntil: null,
      status: 'open',
      createdAt: new Date(),
    });
  }

  generateRandomAccessCode() {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  createRoom(doctorId, customRoomName) {
    const suffix = Math.random().toString(36).substring(2, 8);
    const roomId = customRoomName || `chav-${suffix}`;
    const acCode = this.generateRandomAccessCode();

    const roomRecord = {
      roomId,
      doctorId,
      acCode,
      acAttempts: 0,
      acLockedUntil: null,
      status: 'open',
      createdAt: new Date(),
    };

    this.roomsMap.set(roomId, roomRecord);

    const baseUrl = 'http://localhost:8080';
    return {
      roomId,
      acCode,
      doctorLink: `${baseUrl}/#/consultation?room=${roomId}&role=doctor`,
      guestLink: `${baseUrl}/#/?room=${roomId}&role=guest&ac=${acCode}`,
    };
  }

  async mintLiveKitToken(roomId, identity, role) {
    const room = this.roomsMap.get(roomId);
    if (room && room.status === 'ended') {
      throw new Error('Room session has ended.');
    }

    try {
      const { AccessToken } = require('livekit-server-sdk');
      const at = new AccessToken(config.LIVEKIT_API_KEY, config.LIVEKIT_API_SECRET, {
        identity,
        ttl: '4h',
      });

      at.addGrant({
        room: roomId,
        roomJoin: true,
        canPublish: role === 'doctor' || role === 'patient',
        canPublishData: true,
        canSubscribe: true,
      });

      return await at.toJwt();
    } catch (e) {
      const payload = {
        iss: config.LIVEKIT_API_KEY,
        sub: identity,
        video: {
          room: roomId,
          roomJoin: true,
          canPublish: role === 'doctor' || role === 'patient',
          canSubscribe: true,
        },
      };
      return signJwt(payload, config.LIVEKIT_API_SECRET, 14400);
    }
  }

  updateRoomStatus(roomId, status) {
    const room = this.roomsMap.get(roomId);
    if (!room) throw new Error('Room not found');
    room.status = status;
    this.roomsMap.set(roomId, room);
  }

  getRoomMetadata(roomId, requesterRole, requesterId) {
    const room = this.roomsMap.get(roomId);
    if (!room) throw new Error('Room not found');

    const isOwner = requesterRole === 'doctor' && room.doctorId === requesterId;
    return {
      roomId: room.roomId,
      doctorId: room.doctorId,
      status: room.status,
      createdAt: room.createdAt,
      ...(isOwner ? { acCode: room.acCode } : {}),
    };
  }

  verifyRoomAccessCode(roomId, code) {
    let room = this.roomsMap.get(roomId);
    if (!room) {
      room = {
        roomId,
        doctorId: 'Dr. System',
        acCode: '1111',
        acAttempts: 0,
        acLockedUntil: null,
        status: 'open',
        createdAt: new Date(),
      };
      this.roomsMap.set(roomId, room);
    }

    const now = new Date();
    if (room.acLockedUntil && now < room.acLockedUntil) {
      return false;
    }

    if (room.acCode === code) {
      room.acAttempts = 0;
      room.acLockedUntil = null;
      this.roomsMap.set(roomId, room);
      return true;
    } else {
      room.acAttempts += 1;
      if (room.acAttempts >= 3) {
        room.acLockedUntil = new Date(now.getTime() + 15 * 60 * 1000);
      }
      this.roomsMap.set(roomId, room);
      return false;
    }
  }
}

const roomsService = new RoomsService();
module.exports = { roomsService };
