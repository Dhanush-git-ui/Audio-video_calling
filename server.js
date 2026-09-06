import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 5005;

// Middleware
app.use(cors());
app.use(express.json());

// Serve Flutter web build as static files
app.use(express.static(path.join(__dirname, 'build', 'web')));

// API routes (placeholder - integrate with your actual API routes)
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// Catch-all for Flutter SPA - serve index.html for all non-API routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'web', 'index.html'));
});

if (!process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n=============================================================`);
    console.log(`🛡️ AuraCare CHAV Backend Service Running`);
    console.log(`🌐 Server listening on: http://localhost:${PORT}`);
    console.log(`🚀 API Base URL: http://localhost:${PORT}/api`);
    console.log(`🌍 Flutter App: http://localhost:${PORT}`);
    console.log(`=============================================================\n`);
  });
}

export default app;
