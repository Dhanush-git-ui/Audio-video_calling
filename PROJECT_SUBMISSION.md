# 🏥 AuraCare CHAV — Telemedicine Platform

## Project Overview

**AuraCare CHAV** is a comprehensive clinical telehealth platform designed to provide secure, real-time audio/video consultations between doctors and patients. The system combines modern web technologies with biometric verification to ensure secure and compliant telemedicine sessions.

## Project Architecture

### 🏗️ Monorepo Structure

The project is organized as a clean monorepo with two main components:

1. **Backend (Node.js/TypeScript)** — Server-side microservices
2. **Frontend (Flutter)** — Cross-platform application

---

## Backend Architecture

### Tech Stack
- **Node.js** — Runtime environment
- **TypeScript** — Type-safe JavaScript
- **Express.js** — Web framework
- **Supabase** — Database (PostgreSQL) and storage
- **LiveKit** — Real-time audio/video infrastructure
- **JWT** — Authentication
- **Zod** — Input validation

### Backend Services

#### 1. Authentication Module (`/api/auth`)
- Doctor and patient login with JWT tokens
- Guest access code verification
- Secure session management
- Role-based access control

#### 2. Room Management (`/api/rooms`)
- LiveKit room creation and management
- Secure token minting with role-based publish/subscribe grants
- Room locking/unlocking mechanisms
- 3-attempt access control for guest codes

#### 3. Biometric Verification (`/api/biometric`)
- Secure file uploads to Supabase storage
- Biometric audit logging
- Compliance tracking
- No client-side secrets — all operations server-authoritative

#### 4. AI Scoring (`/api/scoring`)
- Raw signal processing from biometric captures
- 90% threshold pass/fail calculation
- Server-authoritative decision making
- Comprehensive audit trail

### Database Schema (Supabase/PostgreSQL)

The platform uses a carefully designed database schema:

| Table | Purpose |
|-------|---------|
| `sessions` | User authentication sessions with expiration |
| `rooms` | LiveKit room metadata and access control |
| `biometric_captures` | Biometric verification records |
| `biometric_audit_logs` | Complete audit trail of verifications |
| `doctor_availability` | Doctor online/offline status |

---

## Frontend Architecture

### Tech Stack
- **Flutter** — Cross-platform UI framework
- **Dart** — Programming language
- **LiveKit Client** — Real-time audio/video
- **GoRouter** — Routing and navigation
- **Provider** — State management
- **MediaPipe** — On-device ML for facial landmarks
- **Flutter Web** — Web deployment target

### Frontend Features

#### 1. User Authentication & Roles
- Doctor login
- Patient login
- Guest access with verification codes
- Role-based UI adaptation

#### 2. Virtual Waiting Room
- Pre-consultation environment
- Camera/microphone testing
- Biometric verification check
- MediaPipe facial landmark detection

#### 3. Consultation Room
- Real-time audio/video streaming
- Chat functionality with unread badges
- Whiteboard collaboration
- Background blur (MediaPipe)
- Noise cancellation
- Live photo capture
- Camera flip
- Guest invitation

#### 4. Clinical Panel
- Emotion tracker with real-time analysis
- Patient vital signs monitoring
- Clinical notes interface
- AI-powered scoring display

#### 5. Additional Features
- Picture-in-Picture mode
- Screen sharing
- Session recording
- Multi-language support
- Responsive design for mobile/desktop

---

## Security Features

### 🔒 Security Guarantees
1. **No Client-Side Secrets** — No application holds Supabase Service Role keys or LiveKit Secrets
2. **Server-Side Token Minting** — LiveKit video/audio tokens are minted server-side with strict role-based grants
3. **Authoritative AI Scoring** — The 90% biometric pass/fail decision is calculated exclusively by the backend
4. **JWT Authentication** — Secure token-based authentication
5. **Rate Limiting** — Protection against brute force attacks
6. **CORS Configuration** — Controlled cross-origin requests

---

## Deployment

### Vercel Deployment
The application is deployed on Vercel with:
- Flutter web build automation
- Node.js server hosting
- Custom domain configuration
- Environment variable management

### Build Process
1. Flutter web compilation
- Static asset optimization
- Font tree-shaking
- Wasm compatibility checks

2. Server startup
- Express server initialization
- Static file serving
- API route registration

---

## Technical Highlights

### Real-Time Communication
- **LiveKit** provides low-latency audio/video streaming
- **WebRTC** for peer-to-peer connections
- **SFU** (Selective Forwarding Unit) architecture for scalability

### Biometric Security
- **MediaPipe** for on-device facial landmark detection
- **Liveness detection** to prevent spoofing
- **Multi-factor verification** (face + iris + body metrics)
- **Server-authoritative scoring** for unbiased results

### Cross-Platform
- Single Flutter codebase targets:
  - Web (Chrome, Edge, Firefox)
  - Android
  - iOS
  - Windows
  - macOS

### AI Integration
- Real-time emotion tracking
- Clinical decision support
- Automated scoring algorithms
- Audit trail generation

---

## Project Impact

This telemedicine platform addresses several critical healthcare needs:

1. **Remote Consultations** — Enable doctor-patient interactions without physical presence
2. **Secure Verification** — Biometric authentication ensures patient identity
3. **Clinical Efficiency** — AI-powered tools assist doctors in diagnosis
4. **Compliance** — Complete audit trails for regulatory requirements
5. **Accessibility** — Cross-platform support reaches patients on any device

---

## Technologies Used

### Backend
- Node.js, TypeScript, Express.js
- Supabase (PostgreSQL)
- LiveKit Server SDK
- JWT, Zod, CORS

### Frontend
- Flutter, Dart
- LiveKit Client
- GoRouter, Provider
- MediaPipe, Flutter Web
- Flutter Animate, File Picker, Permission Handler

### DevOps
- Vercel (deployment)
- GitHub (version control)
- npm/yarn (package management)
- Docker (containerization - optional)

---

## Future Enhancements

1. **Video Recording** — Session recording with patient consent
2. **EHR Integration** — Electronic Health Record connectivity
3. **Multi-language** — Expanded language support
4. **Advanced AI** — Predictive analytics for patient outcomes
5. **Mobile Apps** — Native iOS/Android app optimization
6. **Telehealth APIs** — Integration with existing healthcare systems

---

## Team & Roles

**Project Developed By:** Dhanush

**Role:** Full-Stack Developer
- Backend API design and implementation
- Frontend Flutter application development
- Database schema design
- Security implementation
- Deployment configuration

---

## 🎯 Interview Q&A — Team Leader Questions

### Q1: Why did you choose a monorepo architecture instead of separate repositories?

**Answer:**
The monorepo approach provides several advantages for this telemedicine platform:
- **Shared Dependencies** — Both backend and frontend can share TypeScript types and Zod schemas
- **Consistent Tooling** — Single `package.json` with unified build scripts
- **Simplified Deployment** — One `vercel.json` configures the entire stack
- **Easier Code Sharing** — API contracts can be imported directly by the frontend
- **Atomic Changes** — Backend and frontend updates can be deployed together safely

### Q2: How does the biometric verification work technically?

**Answer:**
The biometric verification uses a multi-layered approach:
1. **Client-Side Capture** — MediaPipe processes facial landmarks directly in the browser
2. **Feature Extraction** — Iris, face, body, and liveness metrics are computed locally
3. **Secure Upload** — Only processed metrics (not raw images) are sent to the backend
4. **Server-Side Scoring** — The backend applies the 90% threshold algorithm
5. **Audit Trail** — All verifications are logged with detailed scores and failure reasons

### Q3: Why is the AI scoring done server-side rather than client-side?

**Answer:**
This is a critical security decision:
- **Prevents Tampering** — Client-side scoring could be manipulated
- **Consistent Thresholds** — The 90% pass/fail logic stays centralized
- **Audit Integrity** — Scores cannot be altered after calculation
- **Regulatory Compliance** — Healthcare regulations require authoritative decisions
- **Model Updates** — Scoring algorithms can be updated without client redeployment

### Q4: How do you handle LiveKit room security?

**Answer:**
Room security is enforced through multiple layers:
- **Server-Side Token Minting** — Only the backend can create valid LiveKit tokens
- **Role-Based Grants** — Doctors get publish+subscribe, patients get subscribe-only
- **Room Locking** — After 3 failed guest attempts, the room locks for 5 minutes
- **Access Codes** — Guests must provide valid codes before joining
- **Audit Logging** — All room access attempts are recorded

### Q5: What database did you choose and why?

**Answer:**
**Supabase (PostgreSQL)** was chosen for:
- **Built-in Auth** — Seamless JWT integration with the platform's auth system
- **Real-Time Subscriptions** — Live updates for doctor availability and chat
- **Storage** — Built-in file storage for biometric captures
- **RLS** — Row-level security for data isolation
- **PostgreSQL** — Full SQL capabilities with JSONB support for flexible schemas

### Q6: How does the Flutter web build work with Vercel?

**Answer:**
The deployment pipeline:
1. **Build Phase** — `vercel-build.sh` compiles Flutter to web using a cloned Flutter SDK
2. **Asset Optimization** — Font tree-shaking reduces Material Icons by 98.9%
3. **Server Startup** — Express serves the built `build/web` directory
4. **SPA Routing** — All non-API routes serve `index.html` for GoRouter compatibility
5. **Static Hosting** — Vercel's CDN distributes the built assets globally

### Q7: What security measures prevent unauthorized access?

**Answer:**
Comprehensive security implementation:
- **JWT Authentication** — Stateless tokens with expiration
- **Rate Limiting** — Prevents brute force attacks
- **CORS Configuration** — Restricts cross-origin requests
- **Input Validation** — Zod schemas prevent injection attacks
- **Environment Secrets** — No secrets in client code
- **Structured Logging** — JSON logs exclude sensitive data
- **HTTPS Only** — All communications encrypted

### Q8: How do you handle real-time communication?

**Answer:**
Real-time features use:
- **LiveKit SFU** — Selective Forwarding Unit for scalable video
- **WebRTC** — Peer-to-peer audio/video streaming
- **WebSocket** — Bidirectional communication for chat
- **State Management** — Provider pattern for UI synchronization
- **Offline Support** — Caching for network resilience

### Q9: What was the biggest technical challenge?

**Answer:**
The biggest challenge was **biometric verification on web**:
- **MediaPipe Integration** — Required careful JS/Flutter interop
- **Performance** — Real-time facial landmark detection at 30+ FPS
- **Accuracy** — Balancing liveness detection with false rejection rates
- **Cross-Platform** — Ensuring consistent performance across browsers

### Q10: How do you ensure code quality?

**Answer:**
Quality assurance through:
- **TypeScript** — Compile-time type checking
- **Zod Validation** — Runtime input validation
- **Unit Tests** — Scoring math and lockout logic tests
- **Structured Logging** — JSON logs for monitoring
- **Error Handling** — Global error handler with stack traces
- **Code Reviews** — Peer review before deployment

### Q11: What would you improve if given more time?

**Answer:**
Priority improvements:
1. **Video Recording** — With patient consent and secure storage
2. **EHR Integration** — HL7/FHIR standards for health records
3. **Advanced AI** — Predictive analytics for patient outcomes
4. **Mobile Optimization** — Native iOS/Android app improvements
5. **Telehealth APIs** — Integration with existing hospital systems

### Q12: How do you handle deployment and scaling?

**Answer:**
Deployment strategy:
- **Vercel** — Automatic builds and global CDN
- **Supabase** — Auto-scaling PostgreSQL with real-time
- **LiveKit** — Scalable SFU architecture
- **Environment Config** — All settings via environment variables
- **Monitoring** — Structured logs and health endpoints

---

## 📋 Project Checklist

Before submission, verify:

- [x] All features implemented as described
- [x] Backend API endpoints functional
- [x] Flutter web build successful
- [x] Vercel deployment configured
- [x] Database schema complete
- [x] Security measures in place
- [x] Documentation comprehensive
- [x] Code quality standards met
- [x] Real-time communication working
- [x] Biometric verification functional

---

## Contact

For questions or demonstrations, please contact the project developer.

---

*This project was developed as part of an internship program, demonstrating full-stack development capabilities in modern telehealth technology.*