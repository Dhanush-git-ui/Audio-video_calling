const jwt = require('jsonwebtoken');

module.exports = async (req, res) => {
  // Set CORS headers so the Flutter client can fetch the token from any origin if needed
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const room = req.query.room || (req.body && req.body.room);
    const name = req.query.name || (req.body && req.body.name);

    if (!room || !name) {
      return res.status(400).json({ error: 'Missing room or name parameter' });
    }

    // Read keys from environment variables (configured securely in Vercel settings)
    // with safe fallback for local development.
    const apiKey = process.env.LIVEKIT_API_KEY || 'APIjazQB9UmJJdg';
    const apiSecret = process.env.LIVEKIT_API_SECRET || 'Bp2ifhyMjeqNVZIoVkNRDMfan8X5pGSe7fmLgqtPR5TF';

    const now = Math.floor(Date.now() / 1000);
    // Secure token expiration: 2 hours instead of 24 hours
    const exp = now + (2 * 60 * 60);

    const payload = {
      iss: apiKey,
      sub: name,
      nbf: now,
      exp: exp,
      video: {
        room: room,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
      }
    };

    const token = jwt.sign(payload, apiSecret);

    return res.status(200).json({ token });
  } catch (error) {
    console.error('Error generating token:', error);
    return res.status(500).json({ error: 'Failed to generate token' });
  }
};
