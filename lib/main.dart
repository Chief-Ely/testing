import 'package:flutter/material.dart';
import 'transcription_controller.dart';

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
            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _controller.isConnected
                    ? Colors.green[100]
                    : Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _controller.isConnected ? Icons.check_circle : Icons.error,
                    color: _controller.isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _controller.isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color:
                          _controller.isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recording Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _controller.isRecording
                    ? Colors.orange[100]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _controller.isRecording ? Icons.mic : Icons.mic_off,
                    color:
                        _controller.isRecording ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _controller.isRecording ? 'Recording...' : 'Not Recording',
                    style: TextStyle(
                      color:
                          _controller.isRecording ? Colors.orange : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Transcription Text
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Transcription will appear here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),

            const SizedBox(height: 20),

            // Control Buttons
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
}
