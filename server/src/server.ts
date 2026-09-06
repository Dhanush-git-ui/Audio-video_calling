import { app } from './app.js';
import { ENV } from './config/env.js';

const PORT = parseInt(ENV.PORT, 10) || 5005;

if (!process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running at http://localhost:${PORT}`);
  });
}

export default app;
