import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import { ENV } from './config/env.js';
import authRoutes from './modules/auth/auth.routes.js';
import roomsRoutes from './modules/rooms/rooms.routes.js';
import biometricRoutes from './routes/biometric.routes.js';
import scoringRoutes from './routes/scoring.routes.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const app = express();

// Structured JSON Logger
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (req.path.startsWith('/api')) {
      console.log(JSON.stringify({ timestamp: new Date().toISOString(), method: req.method, path: req.path, status: res.statusCode, durationMs: duration, ip: req.ip }));
    }
  });
  next();
});

app.use(cors({ origin: ENV.ALLOWED_ORIGINS === '*' ? true : ENV.ALLOWED_ORIGINS.split(','), credentials: true }));
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// Health endpoint for Vercel
app.get('/api/health', (_req, res) => res.json({ status: 'ok', message: 'Server is running' }));

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/rooms', roomsRoutes);
app.use('/api/biometric', biometricRoutes);
app.use('/api/scoring', scoringRoutes);

// Add getToken alias for Flutter shared_state.dart compatibility
app.get('/api/getToken', (req, res) => {
  res.status(301).json({ redirect: `/api/rooms/${req.query.room}/token` });
});

// Static hosting
const webPath = path.join(__dirname, '..', '..', 'build', 'web');
try {
  app.use(express.static(webPath));
  app.get('*', (req, res) => {
    if (req.path.startsWith('/api')) return res.status(404).json({ success: false, error: 'Not found' });
    res.sendFile(path.join(webPath, 'index.html'));
  });
} catch {
  // If build/web doesn't exist yet (dev mode), skip static hosting
}

// Global error handler
app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  console.error(JSON.stringify({ timestamp: new Date().toISOString(), error: err.message, stack: err.stack }));
  res.status(500).json({ success: false, error: 'Internal Server Error' });
});
