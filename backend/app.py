import os
import json
import requests
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from openai import OpenAI
from elevenlabs import ElevenLabs, VoiceSettings
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime
import base64

app = Flask(__name__)
CORS(app)

client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))
elevenlabs_client = ElevenLabs(api_key=os.environ.get('ELEVENLABS_API_KEY'))
news_api_key = os.environ.get('NEWS_API_KEY')

AUDIO_DIR = 'generated_audio'
os.makedirs(AUDIO_DIR, exist_ok=True)

scheduler = BackgroundScheduler()
scheduler.start()

US_CITIES = [
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia",
    "San Antonio", "San Diego", "Dallas", "San Jose", "Austin", "Jacksonville",
    "Fort Worth", "Columbus", "Charlotte", "San Francisco", "Indianapolis",
    "Seattle", "Denver", "Boston", "El Paso", "Nashville", "Detroit", "Oklahoma City",
    "Portland", "Las Vegas", "Memphis", "Louisville", "Baltimore", "Milwaukee",
    "Albuquerque", "Tucson", "Fresno", "Sacramento", "Kansas City", "Long Beach",
    "Mesa", "Atlanta", "Colorado Springs", "Virginia Beach", "Raleigh", "Omaha",
    "Miami", "Oakland", "Minneapolis", "Tulsa", "Wichita", "New Orleans", "Arlington",
    "Cleveland", "Bakersfield", "Tampa", "Aurora", "Anaheim", "Honolulu", "Santa Ana",
    "Riverside", "Corpus Christi", "Lexington", "Stockton", "Henderson", "Saint Paul",
    "Cincinnati", "St. Louis", "Pittsburgh", "Greensboro", "Lincoln", "Anchorage",
    "Plano", "Orlando", "Irvine", "Newark", "Durham", "Chula Vista", "Toledo",
    "Fort Wayne", "St. Petersburg", "Laredo", "Jersey City", "Chandler", "Madison",
    "Lubbock", "Scottsdale", "Reno", "Buffalo", "Gilbert", "Glendale", "North Las Vegas",
    "Winston-Salem", "Chesapeake", "Norfolk", "Fremont", "Garland", "Irving", "Hialeah",
    "Richmond", "Boise", "Spokane", "Baton Rouge"
]

@app.route('/api/search-cities', methods=['GET'])
def search_cities():
    query = request.args.get('q', '').lower()
    if len(query) < 2:
        return jsonify({'cities': []})
    
    suggestions = [city for city in US_CITIES if query in city.lower()][:10]
    return jsonify({'cities': suggestions})

@app.route('/api/generate-podcast', methods=['POST'])
def generate_podcast():
    data = request.json
    city = data.get('city')
    voice_id = data.get('voice_id', 'Rachel')
    
    if not city:
        return jsonify({'error': 'City is required'}), 400
    
    try:
        news_articles = fetch_local_news(city)
        
        if not news_articles:
            return jsonify({'error': f'No local news found for {city}'}), 404
        
        script = generate_radio_script(city, news_articles)
        
        audio_filename = f"{city.replace(' ', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp3"
        audio_path = os.path.join(AUDIO_DIR, audio_filename)
        
        generate_voice_audio(script, voice_id, audio_path)
        
        return jsonify({
            'success': True,
            'script': script,
            'audio_url': f'/audio/{audio_filename}',
            'city': city
        })
        
    except Exception as e:
        print(f"Error generating podcast: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/audio/<filename>')
def serve_audio(filename):
    return send_from_directory(AUDIO_DIR, filename)

@app.route('/api/schedule-podcast', methods=['POST'])
def schedule_podcast():
    data = request.json
    city = data.get('city')
    voice_id = data.get('voice_id', 'Rachel')
    time_str = data.get('time', '07:00')
    
    if not city:
        return jsonify({'error': 'City is required'}), 400
    
    hour, minute = map(int, time_str.split(':'))
    
    job_id = f"podcast_{city.replace(' ', '_')}"
    
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)
    
    scheduler.add_job(
        func=generate_scheduled_podcast,
        trigger='cron',
        hour=hour,
        minute=minute,
        args=[city, voice_id],
        id=job_id,
        replace_existing=True
    )
    
    return jsonify({
        'success': True,
        'message': f'Podcast scheduled for {city} at {time_str} daily'
    })

def fetch_local_news(city):
    url = 'https://newsapi.org/v2/everything'
    params = {
        'q': f'{city} OR "{city}"',
        'language': 'en',
        'sortBy': 'publishedAt',
        'pageSize': 10,
        'apiKey': news_api_key
    }
    
    response = requests.get(url, params=params)
    
    if response.status_code == 200:
        articles = response.json().get('articles', [])
        return articles[:5]
    else:
        print(f"NewsAPI Error: {response.status_code}")
        return []

def generate_radio_script(city, articles):
    articles_text = "\n\n".join([
        f"Article {i+1}:\nTitle: {article['title']}\nDescription: {article.get('description', 'No description')}\nSource: {article['source']['name']}"
        for i, article in enumerate(articles)
    ])
    
    prompt = f"""You are a professional local radio news host creating a hyper-local morning news podcast for {city}.

Based on these news articles about {city}:

{articles_text}

Create a 10-15 minute radio-style news script with the following structure:
1. Warm introduction welcoming listeners to {city}'s morning news
2. Top 3 local headlines (focus ONLY on {city}-specific news)
3. Community events or local interest stories
4. Brief weather mention (if available in articles)
5. Friendly sign-off

Important guidelines:
- Use a warm, conversational NPR-style tone
- Focus EXCLUSIVELY on hyper-local {city} news - NO national/international headlines
- Explain any technical terms in simple language
- Include ElevenLabs v3 SSML markup for natural speech:
  * Use <break time="0.5s"/> for pauses
  * Use <prosody rate="slow">text</prosody> for emphasis
  * Use <phoneme alphabet="ipa" ph="pronunciation">word</phoneme> for difficult words
- Keep the total script to 10-15 minutes of speaking time
- Make it sound natural and engaging, like a real radio host

Write ONLY the script text, no stage directions or meta-commentary."""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are an expert radio script writer specializing in local news podcasts with warm, conversational delivery."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.7
    )
    
    return response.choices[0].message.content

def generate_voice_audio(script, voice_id, output_path):
    audio = elevenlabs_client.text_to_speech.convert(
        voice_id=voice_id,
        model_id="eleven_turbo_v2_5",
        text=script,
        voice_settings=VoiceSettings(
            stability=0.5,
            similarity_boost=0.75,
            style=0.5,
            use_speaker_boost=True
        )
    )
    
    with open(output_path, 'wb') as f:
        for chunk in audio:
            f.write(chunk)

def generate_scheduled_podcast(city, voice_id):
    try:
        news_articles = fetch_local_news(city)
        
        if not news_articles:
            print(f"No news found for scheduled podcast: {city}")
            return
        
        script = generate_radio_script(city, news_articles)
        
        audio_filename = f"{city.replace(' ', '_')}_scheduled_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp3"
        audio_path = os.path.join(AUDIO_DIR, audio_filename)
        
        generate_voice_audio(script, voice_id, audio_path)
        
        print(f"Scheduled podcast generated: {audio_filename}")
        
    except Exception as e:
        print(f"Error in scheduled podcast generation: {str(e)}")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
