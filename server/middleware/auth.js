const crypto = require('crypto');
const config = require('../config');

function verifyJwt(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid token');
  const [b64Header, b64Payload, signature] = parts;
  const expectedSig = crypto.createHmac('sha256', secret)
    .update(`${b64Header}.${b64Payload}`)
    .digest('base64url');
  if (signature !== expectedSig) throw new Error('Signature mismatch');
  const payload = JSON.parse(Buffer.from(b64Payload, 'base64url').toString('utf8'));
  if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) throw new Error('Token expired');
  return payload;
}

function signJwt(payload, secret, expiresInSeconds = 14400) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = { ...payload, iat: now, exp: now + expiresInSeconds };
  
  const b64Header = Buffer.from(JSON.stringify(header)).toString('base64url');
  const b64Payload = Buffer.from(JSON.stringify(fullPayload)).toString('base64url');
  
  const signature = crypto.createHmac('sha256', secret)
    .update(`${b64Header}.${b64Payload}`)
    .digest('base64url');
    
  return `${b64Header}.${b64Payload}.${signature}`;
}

const authenticateJwt = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Missing or malformed Bearer token.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = verifyJwt(token, config.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Invalid or expired session token.' });
  }
};

const requireRole = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, error: 'Unauthorized: User identity not verified.' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: `Forbidden: Insufficient privileges for role '${req.user.role}'. Required: ${allowedRoles.join(', ')}`,
      });
    }

    if (req.user.role === 'guest') {
      const targetRoom = req.params.room_id || req.body.room_id || req.query.room_id;
      if (targetRoom && req.user.roomId && req.user.roomId !== targetRoom) {
        return res.status(403).json({
          success: false,
          error: `Forbidden: Guest token for room '${req.user.roomId}' cannot access room '${targetRoom}'.`,
        });
      }
    }

    next();
  };
};

module.exports = { authenticateJwt, requireRole, signJwt, verifyJwt };
