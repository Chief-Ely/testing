// lib/main.dart
import 'package:flutter/material.dart';
import 'services/audio_ws_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AudioWsService _svc = AudioWsService();
  String _transcription = "";
  bool _connected = false;
  bool _recording = false;

  final String wsUrl = "wss://exportable-unsteamed-macy.ngrok-free.dev/ws/transcribe"; // <-- update here

  @override
  void initState() {
    super.initState();
    _svc.onTranscript = (text) {
      setState(() {
        // append text with newline
        _transcription = _transcription + (text.trim().isEmpty ? "" : ("\n" + text.trim()));
      });
    };
    _svc.onConnected = () {
      setState(() => _connected = true);
    };
    _svc.onDisconnected = () {
      setState(() => _connected = false);
    };
    _svc.onError = (err) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $err")));
    };

    // initialize with given ws
    _svc.init(wsUrl: wsUrl).catchError((e) {
      print("Init error: $e");
    });
  }

  @override
  void dispose() {
    _svc.dispose();
    super.dispose();
  }

  void _toggleConnect() async {
    if (_connected) {
      await _svc.disconnectWebSocket();
    } else {
      try {
        await _svc.connectWebSocket();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("WS connect error: $e")));
      }
    }
  }

  void _toggleRecording() async {
    if (!_recording) {
      await _svc.startRecordingAndStreaming();
      setState(() => _recording = true);
    } else {
      await _svc.stopRecordingAndStreaming();
      setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Whisper Test',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Realtime Whisper Test'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _toggleConnect,
                    child: Text(_connected ? "Disconnect WS" : "Connect WS"),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _connected ? _toggleRecording : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _recording ? Colors.red : Colors.green,
                    ),
                    child: Text(_recording ? "Stop Mic" : "Start Mic"),
                  )
                ],
              ),
              SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _transcription.isEmpty ? "Transcriptions will appear here..." : _transcription,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
