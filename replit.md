# Hyper-Local Morning News Generator

## Overview

An automated news aggregation and audio generation application that creates daily hyper-local morning news podcasts for US cities. The system combines a Flutter web frontend with a Flask backend, integrating NewsAPI for local news, OpenAI for script generation, and ElevenLabs for text-to-speech conversion.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture

**Technology Stack:** Flutter 3.32.0 (web, iOS, Android)
- **Framework:** Flutter cross-platform (web, iOS, Android) running on port 5000
- **UI Components:** Material Design with autocomplete, voice selection, scheduling, and playback controls
- **HTTP Communication:** http package for REST API integration with backend
- **Audio Playback:** audioplayers package for streaming audio from backend
- **Development Tools:** Dart 3.8.0
- **Platform Support:** 
  - ✅ Web (production deployment on Replit)
  - ✅ iOS (requires local Xcode build)
  - ✅ Android (requires local Android Studio build)

**Key Features:**
- City search with real-time autocomplete (10 suggestions, minimum 2 characters)
- Voice selection from 6 ElevenLabs v3 voice options
- On-demand podcast generation
- Daily scheduling with time selection
- Audio playback with script viewer
- Cross-platform support with platform-aware backend URL handling

### Backend Architecture

**Technology Stack:** Python Flask REST API (port 5000)
- **Framework:** Flask with CORS enabled for Flutter web access
- **Background Processing:** APScheduler for scheduled daily podcast generation
- **Audio Storage:** Local filesystem in `generated_audio` directory
- **Production Server:** Gunicorn WSGI server with 2 workers

**API Endpoints:**
1. `/api/search-cities` - City autocomplete (GET)
2. `/api/voices` - Fetch available ElevenLabs voices dynamically (GET)
3. `/api/generate-podcast` - Generate podcast on-demand (POST)
4. `/api/schedule-podcast` - Schedule daily generation (POST)
5. `/audio/<filename>` - Serve generated audio files (GET)
6. `/` - Health check endpoint & serves Flutter web app

**Key Architectural Decisions:**

1. **City Search Functionality**
   - In-memory array of 100 major US cities
   - Substring matching for fast autocomplete
   - Returns maximum 10 suggestions
   - Decision: No database overhead for fixed, small dataset

2. **News Fetching Strategy**
   - NewsAPI.org integration for real-time local news
   - Filters by city name with hyper-local focus
   - Fetches top 5 most recent articles per city
   - Decision: Focus ONLY on city-specific news, excludes national/international

3. **Script Generation Pipeline**
   - Anthropic Claude 4.5 Sonnet (claude-sonnet-4-20250514) for content generation
   - Structured format: intro → headlines → community events → weather → sign-off
   - NPR-style warm, conversational tone
   - Includes ElevenLabs v3 SSML markup for natural speech:
     * `<break time="0.5s"/>` for pauses
     * `<prosody>` tags for emphasis
     * `<phoneme>` for pronunciation
   - Target duration: 10-15 minutes
   - Decision: Switched from OpenAI to Claude for better script quality and reliability

4. **Voice Generation & Selection**
   - ElevenLabs API with eleven_turbo_v2_5 model
   - **Dynamic Voice Loading:** Fetches all available voices from user's ElevenLabs account via API
   - **Optimization Highlighting:** "Premade" voices are marked with ✓ Optimized badge
   - **Smart Sorting:** Optimized voices appear first in dropdown for best quality
   - Configurable voice parameters (stability, similarity, style)
   - Speaker boost enabled for professional quality
   - Voice selection includes all voices with proper permissions

5. **Scheduling System**
   - APScheduler with cron triggers
   - Per-city job registration with unique IDs
   - User-configurable daily generation time
   - Limitation: In-memory storage (schedules reset on server restart)
   - Decision: Suitable for current scope, persistent storage can be added if needed

6. **Podcast Publishing**
   - Auto-generation creates timestamped MP3 files
   - Files stored in local filesystem
   - Served via Flask static file endpoint
   - Naming: `{city}_scheduled_{timestamp}.mp3`

### External Dependencies

**API Services:**
- **Anthropic API:** Claude 4.5 Sonnet for script generation (key: ANTHROPIC_API_KEY)
- **ElevenLabs API:** Text-to-speech conversion with dynamic voice loading (key: ELEVENLABS_API_KEY)
- **NewsAPI:** Local news aggregation (key: NEWS_API_KEY)

**Python Packages:**
- flask, flask-cors - Web framework and CORS support
- requests - HTTP client for API calls
- anthropic - Anthropic Claude SDK
- elevenlabs - ElevenLabs SDK
- apscheduler - Background job scheduling
- gunicorn - Production WSGI server

**Flutter Packages:**
- http ^1.1.0 - HTTP client
- audioplayers ^5.2.1 - Audio playback
- intl ^0.19.0 - Date/time formatting
- cupertino_icons ^1.0.8 - iOS-style icons

**Development Tools:**
- flutter_lints ^5.0.0 - Dart code quality

## Deployment Configuration

**Development Workflow:**
- Backend: `cd backend && python app.py` (port 5000, webview) - Serves both Flutter frontend and API backend

**Production Deployment:**
- **Target:** Autoscale deployment (scales to zero when idle)
- **Server:** Gunicorn WSGI with 2 workers (120s timeout)
- **Command:** `gunicorn --bind=0.0.0.0:5000 --workers=2 --timeout=120 backend.app:app`
- **Health Check:** `/` endpoint serves Flutter app (200 OK)

**Environment Variables Required:**
- `ANTHROPIC_API_KEY` - Anthropic Claude authentication
- `ELEVENLABS_API_KEY` - ElevenLabs authentication (requires voices_read permission)
- `NEWS_API_KEY` - NewsAPI authentication

### Mobile Platform Deployment (iOS & Android)

**Important:** Replit only supports mobile development through Expo/React Native. Flutter mobile apps must be built locally or using external CI/CD services.

**Prerequisites:**
- **iOS:** macOS with Xcode 14+ and iOS development setup
- **Android:** Android Studio with Android SDK and emulator
- **Flutter:** Flutter SDK installed locally (matching version 3.32.0)

**Building for Mobile:**

1. **Clone the Repository Locally:**
   ```bash
   git clone <your-replit-repo-url>
   cd <project-directory>
   ```

2. **Configure Backend URL:**
   Mobile apps need to know where the backend API is hosted. Use the `--dart-define` flag:
   
   ```bash
   # For development (local backend)
   flutter run --dart-define=BACKEND_URL=http://localhost:5000
   
   # For Android emulator (special localhost mapping)
   flutter run --dart-define=BACKEND_URL=http://10.0.2.2:5000
   
   # For production (Replit deployment)
   flutter run --dart-define=BACKEND_URL=https://your-replit-url.repl.co
   ```

3. **iOS Build Steps:**
   ```bash
   cd news_generator
   
   # Debug build for simulator
   flutter run -d ios --dart-define=BACKEND_URL=<your-backend-url>
   
   # Release build for physical device
   flutter build ios --release --dart-define=BACKEND_URL=<your-backend-url>
   ```
   
   **iOS Notes:**
   - NSAppTransportSecurity is configured to allow HTTP connections (for development)
   - For production, use HTTPS backend URLs
   - Requires Apple Developer account for physical device deployment

4. **Android Build Steps:**
   ```bash
   cd news_generator
   
   # Debug build for emulator/device
   flutter run -d android --dart-define=BACKEND_URL=<your-backend-url>
   
   # Release APK
   flutter build apk --release --dart-define=BACKEND_URL=<your-backend-url>
   
   # Release App Bundle (for Play Store)
   flutter build appbundle --release --dart-define=BACKEND_URL=<your-backend-url>
   ```
   
   **Android Notes:**
   - INTERNET permission is already configured in AndroidManifest.xml
   - For emulator, use `http://10.0.2.2:5000` to reach host machine's localhost
   - For production, use the actual Replit deployment URL

**Mobile Build Constraints:**
- ⚠️ Cannot build/test mobile apps on Replit (no Xcode/Android SDK)
- ⚠️ Must use local development environment or CI/CD services
- ⚠️ Backend must be accessible via network URL (not localhost relative paths)
- ✅ Code is platform-neutral and ready for mobile deployment
- ✅ All platforms share the same Dart codebase

**Production Mobile Deployment:**
1. Deploy backend to Replit (autoscale deployment)
2. Get production URL (e.g., `https://your-app.repl.co`)
3. Build mobile apps with production URL:
   ```bash
   flutter build ios --release --dart-define=BACKEND_URL=https://your-app.repl.co
   flutter build apk --release --dart-define=BACKEND_URL=https://your-app.repl.co
   ```
4. Submit to App Store (iOS) and Google Play (Android)

**Critical Requirements Met:**
- ✅ Hyper-local focus (city-specific news only)
- ✅ 10-15 minute runtime per episode
- ✅ Professional NPR-style tone
- ✅ Structured segments format
- ✅ Daily automated scheduling
- ✅ No manual editing required
- ✅ Infinite city scalability
- ✅ ElevenLabs v3 markup integration
- ✅ Fully automated pipeline

## Recent Changes (September 30, 2025)

### AI and API Improvements
- Switched AI model from OpenAI GPT to Anthropic Claude 4.5 Sonnet for improved script quality
- Implemented dynamic voice loading from ElevenLabs API with "Optimized" badges for premade voices
- Smart voice sorting: optimized/premade voices appear first in dropdown
- All API integrations working: Claude 4.5, ElevenLabs (with voices_read permission), NewsAPI

### Deployment Configuration
- Added production deployment configuration with Gunicorn WSGI server
- Configured autoscale deployment with health check endpoint
- Production-ready deployment setup with 2 Gunicorn workers and 120s timeout

### Mobile Platform Support (iOS & Android)
- Added iOS and Android platform scaffolding to Flutter project (62 new platform-specific files)
- Implemented platform-aware backend URL handling (web uses relative URLs, mobile requires BACKEND_URL)
- Configured iOS NSAppTransportSecurity to allow HTTP connections for development
- Added Android INTERNET permission for network requests
- Updated app display names to "Hyper-Local News" for both iOS and Android
- Added iOS and Android build directories to .gitignore
- Created comprehensive mobile build documentation with step-by-step instructions
- **Note:** Mobile apps must be built locally (Replit only supports Expo/React Native for mobile)
