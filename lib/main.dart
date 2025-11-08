// lib/main.dart
import 'package:flutter/material.dart';
import 'audio_service.dart';

void main() {
  runApp(const LiveTranscriptionApp());
}

class LiveTranscriptionApp extends StatelessWidget {
  const LiveTranscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Transcription',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TranscriptionPage(),
    );
  }
}

//---------------------------------------------------------//
// CONTROLLER: wraps AudioService and manages UI state
//---------------------------------------------------------//
class TranscriptionController extends ChangeNotifier {
  final AudioService _audioService =
      AudioService('wss://exportable-unsteamed-macy.ngrok-free.dev/ws'); // Replace with your ngrok WebSocket URL

  bool isConnected = false;
  bool isRecording = false;
  String transcriptionText = '';
  String errorMessage = '';

  Future<void> initialize() async {
    try {
      await _audioService.init();
    } catch (e) {
      errorMessage = "Initialization error: $e";
      notifyListeners();
    }
  }

  Future<void> connectToServer() async {
    try {
      // Just mark connected; connection is made in AudioService.startStreaming()
      isConnected = true;
      transcriptionText = "Connected to server.\n";
      notifyListeners();
    } catch (e) {
      errorMessage = "Connection failed: $e";
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    try {
      await _audioService.startStreaming();
      isRecording = true;
      transcriptionText += "Recording started...\n";
      notifyListeners();
    } catch (e) {
      errorMessage = "Start recording failed: $e";
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    try {
      await _audioService.stopStreaming();
      isRecording = false;
      transcriptionText += "Recording stopped.\n";
      notifyListeners();
    } catch (e) {
      errorMessage = "Stop recording failed: $e";
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await _audioService.dispose();
      isConnected = false;
      isRecording = false;
      transcriptionText += "Disconnected from server.\n";
      notifyListeners();
    } catch (e) {
      errorMessage = "Disconnect failed: $e";
      notifyListeners();
    }
  }

  void clearTranscription() {
    transcriptionText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}

//---------------------------------------------------------//
// UI: TranscriptionPage
//---------------------------------------------------------//
class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  final TranscriptionController _controller = TranscriptionController();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    _setupListeners();
  }

  void _setupListeners() {
    _controller.addListener(() {
      if (_controller.transcriptionText.isNotEmpty) {
        _textController.text = _controller.transcriptionText;
      }

      if (_controller.errorMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_controller.errorMessage)),
        );
      }

      setState(() {}); // trigger rebuild for status changes
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Transcription'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusCard(
              label: _controller.isConnected ? 'Connected' : 'Disconnected',
              color: _controller.isConnected ? Colors.green : Colors.red,
              icon: _controller.isConnected ? Icons.check_circle : Icons.error,
            ),
            const SizedBox(height: 20),
            _buildStatusCard(
              label:
                  _controller.isRecording ? 'Recording...' : 'Not Recording',
              color:
                  _controller.isRecording ? Colors.orange : Colors.grey.shade600,
              icon:
                  _controller.isRecording ? Icons.mic : Icons.mic_off,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Transcription will appear here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _controller.isConnected
                        ? null
                        : _controller.connectToServer,
                    child: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _controller.isConnected && !_controller.isRecording
                            ? _controller.startRecording
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Start Recording',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _controller.isRecording
                        ? _controller.stopRecording
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Stop Recording',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _controller.isConnected ? _controller.disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _controller.clearTranscription,
              child: const Text('Clear Transcription'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
