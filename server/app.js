const express = require('express');
const path = require('path');
const config = require('./config');

const { authService } = require('./modules/auth');
const { roomsService } = require('./modules/rooms');
const { biometricService } = require('./modules/biometric');
const { scoringService } = require('./modules/scoring');
const { authenticateJwt, requireRole } = require('./middleware/auth');

const app = express();

// Zero-dependency CORS Headers Middleware
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// Request Logger
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    if (req.path.startsWith('/api')) {
      console.log(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          method: req.method,
          path: req.path,
          status: res.statusCode,
          durationMs: Date.now() - start,
        })
      );
    }
  });
  next();
});

// --- MODULE 1: AUTH & SESSION GATEWAY ---
app.post('/api/auth/doctor/login', (req, res) => {
  try {
    const { username, password, otp } = req.body;
    const result = authService.loginDoctor(username, password, otp);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(401).json({ success: false, error: err.message });
  }
});

app.post('/api/auth/patient/login', (req, res) => {
  try {
    const { name, mobileOrEmail, otp } = req.body;
    const result = authService.loginPatient(name, mobileOrEmail, otp);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(401).json({ success: false, error: err.message });
  }
});

app.post('/api/auth/guest/verify', (req, res) => {
  try {
    const { roomId, accessCode, name } = req.body;
    const result = authService.verifyGuestAccess(roomId, accessCode, name);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(401).json({ success: false, error: err.message });
  }
});

app.post('/api/auth/logout', authenticateJwt, (req, res) => {
  res.json({ success: true, message: 'Session logged out.' });
});

// --- MODULE 2: LIVEKIT TOKEN & ROOM SERVICE ---
app.post('/api/rooms', authenticateJwt, requireRole(['doctor']), (req, res) => {
  try {
    const doctorId = req.user.userId;
    const { roomName } = req.body;
    const result = roomsService.createRoom(doctorId, roomName);
    res.status(201).json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/rooms/:room_id/token', authenticateJwt, async (req, res) => {
  try {
    const roomId = req.params.room_id;
    const identity = req.body.identity || req.user.userId;
    const role = req.user.role;
    const token = await roomsService.mintLiveKitToken(roomId, identity, role);
    res.json({ success: true, token, roomId, identity, role });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.patch('/api/rooms/:room_id/status', authenticateJwt, requireRole(['doctor']), (req, res) => {
  try {
    const { status } = req.body;
    roomsService.updateRoomStatus(req.params.room_id, status);
    res.json({ success: true, message: `Room status updated to ${status}.` });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.get('/api/rooms/:room_id', authenticateJwt, (req, res) => {
  try {
    const metadata = roomsService.getRoomMetadata(req.params.room_id, req.user.role, req.user.userId);
    res.json({ success: true, data: metadata });
  } catch (err) {
    res.status(404).json({ success: false, error: err.message });
  }
});

app.post('/api/rooms/:room_id/verify-code', (req, res) => {
  const { code } = req.body;
  const isValid = roomsService.verifyRoomAccessCode(req.params.room_id, code);
  if (!isValid) {
    return res.status(401).json({ success: false, error: 'Invalid room access code or session locked out.' });
  }
  res.json({ success: true, message: 'Access code verified.' });
});

// --- MODULE 3: BIOMETRIC STORAGE & AUDIT SERVICE ---
app.post('/api/biometric/capture', authenticateJwt, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { roomId, targetType, imageDataUrl } = req.body;
    const result = await biometricService.storeCapture(userId, roomId, targetType, imageDataUrl);
    res.status(201).json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/biometric/audit', authenticateJwt, async (req, res) => {
  try {
    const record = await biometricService.writeAuditRecord(req.body);
    res.status(201).json({ success: true, data: record });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/biometric/audit/:room_id', authenticateJwt, requireRole(['doctor']), (req, res) => {
  const logs = biometricService.getAuditTrailByRoom(req.params.room_id);
  res.json({ success: true, data: logs });
});

app.get('/api/biometric/capture/:capture_id', authenticateJwt, requireRole(['doctor']), (req, res) => {
  const capture = biometricService.getCaptureById(req.params.capture_id);
  if (!capture) return res.status(404).json({ success: false, error: 'Capture not found' });
  res.json({ success: true, data: capture });
});

// --- MODULE 4: AI BIOMETRIC SCORING MICROSERVICE ---
app.post('/api/scoring/face', authenticateJwt, (req, res) => {
  res.json({ success: true, ...scoringService.calculateFaceScore(req.body) });
});

app.post('/api/scoring/iris', authenticateJwt, (req, res) => {
  res.json({ success: true, ...scoringService.calculateIrisScore(req.body) });
});

app.post('/api/scoring/body', authenticateJwt, (req, res) => {
  res.json({ success: true, ...scoringService.calculateBodyScore(req.body) });
});

app.post('/api/scoring/liveness', authenticateJwt, (req, res) => {
  res.json({ success: true, ...scoringService.calculateLivenessScore(req.body) });
});

app.post('/api/scoring/anti-spoof', authenticateJwt, (req, res) => {
  res.json({ success: true, ...scoringService.calculateAntiSpoofScore(req.body) });
});

app.post('/api/scoring/finalize', authenticateJwt, async (req, res) => {
  try {
    const result = await scoringService.finalizeVerification(req.body);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Serve compiled Flutter Web files statically
const webPath = path.join(process.cwd(), 'build', 'web');
app.use(express.static(webPath));

app.get('*', (req, res) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, error: 'API endpoint not found' });
  }
  res.sendFile(path.join(webPath, 'index.html'));
});

module.exports = app;
