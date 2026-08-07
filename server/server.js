const app = require('./app');
const config = require('./config');

const PORT = parseInt(config.PORT, 10) || 5005;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n=============================================================`);
  console.log(`🛡️ AuraCare CHAV Backend Service Running`);
  console.log(`🌐 Server listening on: http://localhost:${PORT}`);
  console.log(`🚀 API Base URL: http://localhost:${PORT}/api`);
  console.log(`=============================================================\n`);
});
