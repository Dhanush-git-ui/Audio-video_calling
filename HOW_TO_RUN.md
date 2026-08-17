# How to Run the AuraCare CHAV Project

This repository contains both the Node.js backend and the Flutter frontend within the same root directory. Follow these instructions to run the full application locally.

## 1. Prerequisites
- **Node.js** and **npm** (for the backend)
- **Flutter SDK** (for the frontend)
- A **Supabase** project for the database. You will need to execute the `migrations.sql` file in your Supabase SQL Editor to create the necessary tables.

## 2. Environment Setup
Make sure to create a `.env` file in the root directory. You can copy the contents from `.env.example` and fill in your Supabase and LiveKit credentials:
```bash
cp .env.example .env
```

## 3. Running the Backend Server
The backend is an Express application written in TypeScript. It handles authentication, LiveKit token generation, and biometric storage.

Open a terminal in the root directory and run:
```bash
# Install Node.js dependencies
npm install

# Start the development server
npm run dev
```
This uses `tsx` to run the server in watch mode (`server/src/server.ts`).

## 4. Running the Flutter Frontend
The frontend is a cross-platform Flutter application.

Open a separate terminal in the root directory and run:
```bash
# Fetch Flutter packages
flutter pub get

# Run the app on Chrome (Web)
flutter run -d chrome

# Or run on your preferred target platform (e.g., Windows, macOS, Android, iOS):
flutter run -d windows
flutter run -d macos
```

## 5. LiveKit Setup (Optional)
If you are running LiveKit locally rather than using LiveKit Cloud, there is a `livekit_1.13.1_windows_amd64` folder included in the root for Windows users. You can start the LiveKit server using its executable with a development configuration.
