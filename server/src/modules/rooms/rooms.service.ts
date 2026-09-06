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
    this.roomsMap.set('my-consultation-room', {
      roomId: 'my-consultation-room', doctorId: 'Dr. Amanulla Belg',
      acCode: '1111', acAttempts: 0, acLockedUntil: null, status: 'open', createdAt: new Date(),
    });
  }
  generateRandomAccessCode() { return Math.floor(1000 + Math.random() * 9000).toString(); }
  createRoom(doctorId: string, customRoomName?: string) {
    const suffix = Math.random().toString(36).substring(2, 8);
    const roomId = customRoomName || `chav-${suffix}`;
    const acCode = this.generateRandomAccessCode();
    const record: RoomRecord = { roomId, doctorId, acCode, acAttempts: 0, acLockedUntil: null, status: 'open', createdAt: new Date() };
    this.roomsMap.set(roomId, record);
    return { roomId, acCode, doctorLink: `http://localhost:8080/#/consultation?room=${roomId}&role=doctor`, guestLink: `http://localhost:8080/#/?room=${roomId}&role=guest&ac=${acCode}` };
  }
  async mintLiveKitToken(roomId: string, identity: string, role: 'doctor' | 'patient' | 'guest') {
    // Delegate to server-level LiveKit SDK or sign manually
    // Minimal placeholder: return a signed JWT claim structure
    const { ENV } = await import('../../config/env.js');
    const jwt = await import('jsonwebtoken');
    const payload = { iss: ENV.LIVEKIT_API_KEY, sub: identity, video: { room: roomId, roomJoin: true, canPublish: role === 'doctor' || role === 'patient', canSubscribe: true } };
    return jwt.default.sign(payload, ENV.LIVEKIT_API_SECRET, { expiresIn: '4h' });
  }
  updateRoomStatus(roomId: string, status: RoomRecord['status']) {
    const r = this.roomsMap.get(roomId); if (!r) throw new Error('Room not found'); r.status = status; this.roomsMap.set(roomId, r);
  }
  getRoomMetadata(roomId: string, requesterRole: string, requesterId: string) {
    const r = this.roomsMap.get(roomId); if (!r) throw new Error('Room not found');
    const isOwner = requesterRole === 'doctor' && r.doctorId === requesterId;
    return { roomId: r.roomId, doctorId: r.doctorId, status: r.status, createdAt: r.createdAt, ...(isOwner ? { acCode: r.acCode } : {}) };
  }
  verifyRoomAccessCode(roomId: string, code: string) {
    let r = this.roomsMap.get(roomId);
    if (!r) { r = { roomId, doctorId: 'Dr. System', acCode: '1111', acAttempts: 0, acLockedUntil: null, status: 'open', createdAt: new Date() }; this.roomsMap.set(roomId, r); }
    const now = new Date(); if (r.acLockedUntil && now < r.acLockedUntil) return false;
    if (r.acCode === code) { r.acAttempts = 0; r.acLockedUntil = null; this.roomsMap.set(roomId, r); return true; }
    r.acAttempts += 1; if (r.acAttempts >= 3) r.acLockedUntil = new Date(now.getTime() + 15 * 60000);
    this.roomsMap.set(roomId, r); return false;
  }
}
export const roomsService = new RoomsService();
