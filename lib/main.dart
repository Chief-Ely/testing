import 'package:flutter/material.dart';
import 'package:speech_to_text_ultra_tg/speech_to_text_ultra_tg.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech to Text - Tagalog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SpeechToTextPage(),
    );
  }
}

class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({super.key});

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> {
  late SpeechToTextUltra2 speechService;
  bool isListening = false;
  String recognizedText = '';
  String currentLiveText = '';
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the speech service
    speechService = SpeechToTextUltra2(
      ultraCallback: (liveText, finalText, listening) {
        setState(() {
          isListening = listening;
          
          if (!listening && finalText.isNotEmpty) {
            // When speech ends, append the final text to the recognized text
            if (recognizedText.isEmpty) {
              recognizedText = finalText;
            } else {
              recognizedText = '$recognizedText $finalText'.trim();
            }
            currentLiveText = '';
          } else if (listening && liveText.isNotEmpty) {
            // While listening, update the live text for preview
            currentLiveText = liveText;
          }
          
          // Update the text field with both final and live text
          final displayText = '$recognizedText$currentLiveText';
          if (_textController.text != displayText) {
            _textController.text = displayText;
            // Move cursor to end
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          }
        });
      },
      language: 'fil-PH', // Tagalog (Filipino) - Philippines
    );
  }

  void _toggleListening() {
    if (isListening) {
      speechService.stopListening();
    } else {
      speechService.startListening();
    }
  }

  void _clearText() {
    setState(() {
      recognizedText = '';
      currentLiveText = '';
      _textController.clear();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Speech to Text - Tagalog'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: isListening ? Colors.red.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isListening ? Icons.mic : Icons.mic_off,
                    color: isListening ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isListening ? 'Listening...' : 'Not Listening',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isListening ? Colors.red : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Text field for recognized text
            TextField(
              controller: _textController,
              maxLines: 8,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Your speech will appear here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mic button
                FloatingActionButton.large(
                  onPressed: _toggleListening,
                  backgroundColor: isListening ? Colors.red : Colors.deepPurple,
                  child: Icon(
                    isListening ? Icons.stop : Icons.mic,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),

                // Clear button
                FloatingActionButton(
                  onPressed: _clearText,
                  backgroundColor: Colors.orange,
                  child: const Icon(
                    Icons.clear,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Help text
            Text(
              isListening
                  ? 'Tap the stop button to finish'
                  : 'Tap the microphone to start speaking',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
