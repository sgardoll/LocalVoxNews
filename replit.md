# Hyper-Local Morning News Generator

## Overview

An automated news aggregation and audio generation application that creates daily hyper-local morning news podcasts for US cities. The system combines a Flutter web frontend with a Flask backend, integrating NewsAPI for local news, OpenAI for script generation, and ElevenLabs for text-to-speech conversion.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture

**Technology Stack:** Flutter 3.32.0 (web platform)
- **Framework:** Flutter Web running on port 5000
- **UI Components:** Material Design with autocomplete, voice selection, scheduling, and playback controls
- **HTTP Communication:** http package for REST API integration with backend
- **Audio Playback:** audioplayers package for streaming audio from backend
- **Development Tools:** Dart 3.8.0

**Key Features:**
- City search with real-time autocomplete (10 suggestions, minimum 2 characters)
- Voice selection from 6 ElevenLabs v3 voice options
- On-demand podcast generation
- Daily scheduling with time selection
- Audio playback with script viewer

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

- Switched AI model from OpenAI GPT to Anthropic Claude 4.5 Sonnet for improved script quality
- Implemented dynamic voice loading from ElevenLabs API with "Optimized" badges for premade voices
- Added production deployment configuration with Gunicorn WSGI server
- Configured autoscale deployment with health check endpoint
- Smart voice sorting: optimized/premade voices appear first in dropdown
- All API integrations working: Claude 4.5, ElevenLabs (with voices_read permission), NewsAPI
- Production-ready deployment setup with 2 Gunicorn workers and 120s timeout
