import { app } from './app.js';
import { ENV } from './config/env.js';

const PORT = parseInt(ENV.PORT, 10) || 5005;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n=============================================================`);
  console.log(`🛡️ AuraCare CHAV Backend Service Running`);
  console.log(`🌐 Server listening on: http://localhost:${PORT}`);
  console.log(`🚀 API Base URL: http://localhost:${PORT}/api`);
  console.log(`=============================================================\n`);
});
