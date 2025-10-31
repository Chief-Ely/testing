import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';

class TranscriptionController with ChangeNotifier {
  // WebSocket properties
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // Audio recording properties
  late FlutterSoundRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isInitialized = false;

  // Transcription properties
  String _transcriptionText = '';
  String _errorMessage = '';

  // Getters
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  String get transcriptionText => _transcriptionText;
  String get errorMessage => _errorMessage;

  // WebSocket configuration
  static const String _websocketUrl =
      'wss://exportable-unsteamed-macy.ngrok-free.dev/api/v1/ws/transcribe';

  // Audio configuration for Faster-Whisper
  static const int _sampleRate = 16000;
  static const int _chunkDuration = 2000; // milliseconds

  TranscriptionController() {
    _audioRecorder = FlutterSoundRecorder();
  }

  Future<void> initialize() async {
    try {
      // Request microphone permission
      final microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) {
        throw Exception('Microphone permission denied');
      }

      // Initialize audio recorder
      await _audioRecorder.openRecorder();
      _isInitialized = true;

      _clearError();
    } catch (e) {
      _setError('Initialization failed: $e');
    }
  }

  Future<void> connectToServer() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_websocketUrl));
      _isConnected = true;

      // Listen for incoming transcriptions
      _channel!.stream.listen(
        _handleIncomingTranscription,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDisconnect,
      );

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Connection failed: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      if (!_isConnected) {
        throw Exception('Not connected to server');
      }

      if (!_isInitialized) {
        await initialize();
      }

      // Start recording with PCM16 format for Faster-Whisper
      await _audioRecorder.startRecorder(
        toStream: _createAudioStream(),
        codec: Codec.pcm16,
        sampleRate: _sampleRate,
        numChannels: 1, // Mono
      );

      _isRecording = true;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to start recording: $e');
    }
  }

  // Replace with this:
  StreamSink<Uint8List> _createAudioStream() {
    final controller = StreamController<Uint8List>();

    controller.stream.listen((audioData) {
      // Send audio data through WebSocket when connected and recording
      if (_isConnected && _isRecording) {
        _channel?.sink.add(audioData);
      }
    });

    return controller.sink;
  }

  Future<void> stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      _isRecording = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to stop recording: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  void clearTranscription() {
    _transcriptionText = '';
    notifyListeners();
  }

  void _handleIncomingTranscription(dynamic data) {
    try {
      if (data is String) {
        // Parse the JSON response from the server
        final jsonData = _parseJson(data);
        final text = jsonData['text'] as String? ?? '';

        if (text.isNotEmpty) {
          _transcriptionText += ' $text';
          notifyListeners();
        }
      }
    } catch (e) {
      _setError('Failed to process transcription: $e');
    }
  }

  Map<String, dynamic> _parseJson(String data) {
    // Simple JSON parsing - in production, use dart:convert
    try {
      // This is a simplified parser - replace with proper JSON decoding
      if (data.contains('"text"')) {
        final textStart = data.indexOf('"text":"') + 8;
        final textEnd = data.indexOf('"', textStart);
        final text = data.substring(textStart, textEnd);

        return {'text': text};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  void _handleWebSocketError(error) {
    _setError('WebSocket error: $error');
    _isConnected = false;
    notifyListeners();
  }

  void _handleWebSocketDisconnect() {
    _isConnected = false;
    _isRecording = false;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _audioRecorder.closeRecorder();
    super.dispose();
  }
}
