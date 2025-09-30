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

**Technology Stack:** Python Flask REST API (port 8000)
- **Framework:** Flask with CORS enabled for Flutter web access
- **Background Processing:** APScheduler for scheduled daily podcast generation
- **Audio Storage:** Local filesystem in `generated_audio` directory

**API Endpoints:**
1. `/api/search-cities` - City autocomplete (GET)
2. `/api/generate-podcast` - Generate podcast on-demand (POST)
3. `/api/schedule-podcast` - Schedule daily generation (POST)
4. `/audio/<filename>` - Serve generated audio files (GET)

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
   - OpenAI GPT-4o-mini for content generation
   - Structured format: intro → headlines → community events → weather → sign-off
   - NPR-style warm, conversational tone
   - Includes ElevenLabs v3 SSML markup for natural speech:
     * `<break time="0.5s"/>` for pauses
     * `<prosody>` tags for emphasis
     * `<phoneme>` for pronunciation
   - Target duration: 10-15 minutes
   - Decision: Explain technical terms in simple language

4. **Voice Generation**
   - ElevenLabs API with eleven_turbo_v2_5 model
   - Configurable voice parameters (stability, similarity, style)
   - Speaker boost enabled for professional quality
   - Available voices: Rachel, Drew, Clyde, Paul, Domi, Dave
   - Default: Rachel (warm, conversational radio host tone)

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
- **OpenAI API:** GPT models for script generation (key: OPENAI_API_KEY)
- **ElevenLabs API:** Text-to-speech conversion (key: ELEVENLABS_API_KEY)
- **NewsAPI:** Local news aggregation (key: NEWS_API_KEY)

**Python Packages:**
- flask, flask-cors - Web framework and CORS support
- requests - HTTP client for API calls
- openai - OpenAI SDK
- elevenlabs - ElevenLabs SDK
- apscheduler - Background job scheduling
- python-dotenv - Environment variable management

**Flutter Packages:**
- http ^1.1.0 - HTTP client
- audioplayers ^5.2.1 - Audio playback
- intl ^0.19.0 - Date/time formatting
- cupertino_icons ^1.0.8 - iOS-style icons

**Development Tools:**
- flutter_lints ^5.0.0 - Dart code quality

## Deployment Configuration

**Workflows:**
- Backend: `cd backend && python app.py` (port 5000, webview) - Serves both Flutter frontend and API backend

**Environment Variables Required:**
- `OPENAI_API_KEY` - OpenAI authentication
- `ELEVENLABS_API_KEY` - ElevenLabs authentication
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

- Complete rebuild with Flutter web frontend (replaces previous React approach)
- Flask backend implementation with all API integrations
- City autocomplete functionality
- Voice selection with 6 ElevenLabs v3 voices
- On-demand podcast generation
- Daily scheduling system
- Audio playback in browser
- Workflows configured for both frontend and backend
