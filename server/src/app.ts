import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import path from 'path';
import { ENV } from './config/env.js';

import authRoutes from './modules/auth/auth.routes.js';
import roomsRoutes from './modules/rooms/rooms.routes.js';
import biometricRoutes from './modules/biometric/biometric.routes.js';
import scoringRoutes from './modules/scoring/scoring.routes.js';

export const app = express();

// Structured JSON Logger Middleware (Excludes raw image data bytes)
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (req.path.startsWith('/api')) {
      console.log(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          method: req.method,
          path: req.path,
          status: res.statusCode,
          durationMs: duration,
          ip: req.ip,
        })
      );
    }
  });
  next();
});

// CORS Configuration
app.use(
  cors({
    origin: ENV.ALLOWED_ORIGINS === '*' ? true : ENV.ALLOWED_ORIGINS.split(','),
    credentials: true,
  })
);

app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// API Route Groups
app.use('/api/auth', authRoutes);
app.use('/api/rooms', roomsRoutes);
app.use('/api/biometric', biometricRoutes);
app.use('/api/scoring', scoringRoutes);

// Static Web Hosting for Flutter Web Release Build
const webBuildPath = path.join(process.cwd(), 'build', 'web');
app.use(express.static(webBuildPath));

// Single Page Application Fallback for GoRouter
app.get('*', (req: Request, res: Response) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, error: 'API Endpoint Not Found' });
  }
  res.sendFile(path.join(webBuildPath, 'index.html'));
});

// Global Error Handler
app.use((err: any, req: Request, res: Response, next: NextFunction) => {
  console.error(JSON.stringify({ timestamp: new Date().toISOString(), error: err.message, stack: err.stack }));
  res.status(500).json({ success: false, error: 'Internal Server Error' });
});
