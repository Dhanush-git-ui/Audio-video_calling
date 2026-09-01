import { AccessToken } from 'livekit-server-sdk';
import { ENV } from '../../config/env.js';

export interface RoomRecord {
  roomId: string;
  doctorId: string;
  acCode: string;
  acAttempts: number;
  acLockedUntil: Date | null;
  status: 'open' | 'locked' | 'ended';
  createdAt: Date;
}

class RoomsService {
  private roomsMap = new Map<string, RoomRecord>();

  constructor() {
    // Seed default clinical demo room
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

  generateRandomAccessCode(): string {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  async createRoom(doctorId: string, customRoomName?: string): Promise<{ roomId: string; acCode: string; doctorLink: string; guestLink: string }> {
    const suffix = Math.random().toString(36).substring(2, 8);
    const roomId = customRoomName || `chav-${suffix}`;
    const acCode = this.generateRandomAccessCode();

    const roomRecord: RoomRecord = {
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

  async mintLiveKitToken(roomId: string, identity: string, role: 'doctor' | 'patient' | 'guest'): Promise<string> {
    const room = this.roomsMap.get(roomId);
    if (room && room.status === 'ended') {
      throw new Error('Room session has ended.');
    }

    const at = new AccessToken(ENV.LIVEKIT_API_KEY, ENV.LIVEKIT_API_SECRET, {
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
  }

  async updateRoomStatus(roomId: string, status: 'open' | 'locked' | 'ended'): Promise<void> {
    const room = this.roomsMap.get(roomId);
    if (!room) {
      throw new Error('Room not found');
    }
    room.status = status;
    this.roomsMap.set(roomId, room);
  }

  async getRoomMetadata(roomId: string, requesterRole: string, requesterId: string) {
    const room = this.roomsMap.get(roomId);
    if (!room) {
      throw new Error('Room not found');
    }

    // STRICT SECURITY: Strip acCode from non-owner viewers
    const isOwner = requesterRole === 'doctor' && room.doctorId === requesterId;
    return {
      roomId: room.roomId,
      doctorId: room.doctorId,
      status: room.status,
      createdAt: room.createdAt,
      ...(isOwner ? { acCode: room.acCode } : {}),
    };
  }

  async verifyRoomAccessCode(roomId: string, code: string): Promise<boolean> {
    let room = this.roomsMap.get(roomId);
    if (!room) {
      // Auto-create room record for dynamic rooms with default access code
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

    // Check lockout state
    if (room.acLockedUntil && now < room.acLockedUntil) {
      return false;
    }

    if (room.acCode === code) {
      // Reset attempts on successful verification
      room.acAttempts = 0;
      room.acLockedUntil = null;
      this.roomsMap.set(roomId, room);
      return true;
    } else {
      // Increment attempt counter
      room.acAttempts += 1;
      if (room.acAttempts >= 3) {
        room.acLockedUntil = new Date(now.getTime() + 15 * 60 * 1000); // 15 minute lockout
      }
      this.roomsMap.set(roomId, room);
      return false;
    }
  }
}

export const roomsService = new RoomsService();
