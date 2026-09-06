# Vercel Deployment Fix

## Problem
Your Vercel deployment was failing with the error:
```
Error: No entrypoint found which imports express. Found possible entrypoint: server.js
```

This occurred because:
1. The Flutter web build was succeeding (`build/web`)
2. But Vercel couldn't find a valid Express server to serve the built files
3. The old `server.js` was just a CommonJS require statement pointing to a non-existent compiled TypeScript file
4. The `vercel.json` was configured incorrectly for a Node.js + Flutter setup

## Solution Applied

### 1. Updated `server.js`
- Converted to ES modules (matching your `package.json` "type": "module")
- Created a proper Express server that:
  - Serves the Flutter web build from `build/web` as static files
  - Handles SPA routing (serves `index.html` for all non-API routes)
  - Includes a health check endpoint (`/api/health`)
  - Listens on port 5005 or the PORT environment variable

### 2. Updated `vercel.json`
- Changed `buildCommand` to run `bash vercel-build.sh` directly (which builds Flutter)
- Changed `outputDirectory` to `.` (root) so Vercel finds the Node.js server
- Configured functions settings for the server.js
- Kept rewrite rules for SPA routing

### 3. Updated `package.json`
- Changed `start` script from `tsx server/src/server.ts` to `node server.js`
- This ensures Vercel can properly start your server after the build completes

### 4. Created `.vercelignore`
- Excludes unnecessary files from the build to reduce deployment size
- Keeps only essential files needed for production

## How It Works Now

1. **Build Phase**: `vercel-build.sh` runs and builds the Flutter app to `build/web`
2. **Server Phase**: `server.js` starts and:
   - Serves the Flutter static files
   - Routes SPA traffic properly
   - Ready to handle API requests
3. **Result**: Your Flutter app is accessible at your Vercel deployment URL

## Next Steps

To deploy:
1. Commit these changes to your main branch
2. Push to GitHub
3. Vercel will automatically rebuild and deploy
4. Your Flutter app should be visible at your Vercel URL

## Testing Locally

To test the deployment locally:
```bash
bash vercel-build.sh
npm start
```

Then visit `http://localhost:5005` to see your Flutter app.

## Notes

- The server now properly imports Express and serves static files
- SPA routing is configured so that non-API routes serve `index.html`
- The build includes all necessary Flutter web assets
- The Node.js server is lightweight and just serves the pre-built Flutter app
