import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';

String getBackendUrl() {
  if (kIsWeb) {
    return '';
  } else {
    const replitUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (replitUrl.isEmpty) {
      throw Exception(
        'BACKEND_URL not configured. Build with: flutter run --dart-define=BACKEND_URL=your_backend_url'
      );
    }
    return replitUrl;
  }
}

void main() {
  runApp(const NewsGeneratorApp());
}

class NewsGeneratorApp extends StatelessWidget {
  const NewsGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hyper-Local News Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const NewsGeneratorHome(),
    );
  }
}

class NewsGeneratorHome extends StatefulWidget {
  const NewsGeneratorHome({super.key});

  @override
  State<NewsGeneratorHome> createState() => _NewsGeneratorHomeState();
}

class _NewsGeneratorHomeState extends State<NewsGeneratorHome> {
  final TextEditingController _cityController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _selectedVoice;
  String? _generatedAudioUrl;
  String? _generatedScript;
  bool _isGenerating = false;
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 7, minute: 0);
  List<String> _citySuggestions = [];
  bool _isScheduled = false;
  List<Map<String, dynamic>> _availableVoices = [];
  bool _isLoadingVoices = true;

  @override
  void initState() {
    super.initState();
    _fetchVoices();
  }

  Future<void> _fetchVoices() async {
    try {
      final backendUrl = getBackendUrl();
      final response = await http.get(Uri.parse('$backendUrl/api/voices'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final voices = data['voices'] as List;
        setState(() {
          _availableVoices = voices
              .map(
                (voice) => {
                  'id': voice['id'] as String,
                  'name': voice['name'] as String,
                  'is_premade': voice['is_premade'] as bool? ?? false,
                },
              )
              .toList();

          _availableVoices.sort((a, b) {
            final aPremade = a['is_premade'] as bool;
            final bPremade = b['is_premade'] as bool;
            if (aPremade && !bPremade) return -1;
            if (!aPremade && bPremade) return 1;
            return 0;
          });

          if (_availableVoices.isNotEmpty) {
            _selectedVoice = _availableVoices[0]['id'] as String;
          }
          _isLoadingVoices = false;
        });
      } else {
        _useDefaultVoices();
      }
    } catch (e) {
      print('Error fetching voices: $e');
      _useDefaultVoices();
    }
  }

  void _useDefaultVoices() {
    setState(() {
      _availableVoices = [
        {'id': 'Rachel', 'name': 'Rachel', 'is_premade': true},
        {'id': 'Drew', 'name': 'Drew', 'is_premade': true},
        {'id': 'Clyde', 'name': 'Clyde', 'is_premade': true},
        {'id': 'Paul', 'name': 'Paul', 'is_premade': true},
        {'id': 'Domi', 'name': 'Domi', 'is_premade': true},
        {'id': 'Dave', 'name': 'Dave', 'is_premade': true},
      ];
      _selectedVoice = _availableVoices[0]['id'] as String;
      _isLoadingVoices = false;
    });
  }

  Future<void> _searchCities(String query) async {
    if (query.length < 2) {
      setState(() {
        _citySuggestions = [];
      });
      return;
    }

    try {
      final backendUrl = getBackendUrl();
      final response = await http.get(
        Uri.parse('$backendUrl/api/search-cities?q=$query'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _citySuggestions = List<String>.from(data['cities'] ?? []);
        });
      }
    } catch (e) {
      print('Error searching cities: $e');
    }
  }

  Future<void> _generatePodcast() async {
    if (_cityController.text.isEmpty) {
      _showError('Please enter a city name');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedAudioUrl = null;
      _generatedScript = null;
    });

    try {
      final backendUrl = getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/api/generate-podcast'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'city': _cityController.text,
          'voice_id': _selectedVoice,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final backendUrl = getBackendUrl();
        setState(() {
          _generatedAudioUrl = '$backendUrl${data['audio_url']}';
          _generatedScript = data['script'];
          _isGenerating = false;
        });
      } else {
        final error = json.decode(response.body);
        _showError(error['error'] ?? 'Failed to generate podcast');
        setState(() {
          _isGenerating = false;
        });
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _schedulePodcast() async {
    try {
      final backendUrl = getBackendUrl();
      final response = await http.post(
        Uri.parse('$backendUrl/api/schedule-podcast'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'city': _cityController.text,
          'voice_id': _selectedVoice,
          'time':
              '${_scheduledTime.hour}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isScheduled = true;
        });
        _showSuccess(
          'Podcast scheduled for ${_scheduledTime.format(context)} daily',
        );
      } else {
        _showError('Failed to schedule podcast');
      }
    } catch (e) {
      _showError('Error scheduling: $e');
    }
  }

  Future<void> _playPodcast() async {
    if (_generatedAudioUrl != null) {
      await _audioPlayer.play(UrlSource(_generatedAudioUrl!));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyper-Local Morning News'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Generate Your Daily Local News Podcast',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City Name',
                hintText: 'Start typing your city...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
              onChanged: _searchCities,
            ),

            if (_citySuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _citySuggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text(_citySuggestions[index]),
                      onTap: () {
                        setState(() {
                          _cityController.text = _citySuggestions[index];
                          _citySuggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            _isLoadingVoices
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedVoice,
                    decoration: const InputDecoration(
                      labelText: 'Voice',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.record_voice_over),
                    ),
                    items: _availableVoices.map((voice) {
                      final isPremade = voice['is_premade'] as bool? ?? false;
                      return DropdownMenuItem(
                        value: voice['id'] as String,
                        child: Row(
                          children: [
                            Expanded(child: Text(voice['name'] as String)),
                            if (isPremade)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.shade700,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Optimized',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVoice = value;
                      });
                    },
                  ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generatePodcast,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle),
              label: Text(
                _isGenerating ? 'Generating...' : 'Generate Podcast Now',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Schedule for Daily Briefing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text('Schedule Time: ${_scheduledTime.format(context)}'),
              trailing: const Icon(Icons.edit),
              onTap: _selectTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _cityController.text.isEmpty ? null : _schedulePodcast,
              icon: Icon(_isScheduled ? Icons.check_circle : Icons.schedule),
              label: Text(
                _isScheduled ? 'Scheduled' : 'Schedule Daily Generation',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isScheduled ? Colors.green : null,
              ),
            ),

            if (_generatedAudioUrl != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              const Text(
                'Generated Podcast',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _playPodcast,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Podcast'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 16),

              if (_generatedScript != null) ...[
                ExpansionTile(
                  title: const Text('View Script'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_generatedScript!),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
