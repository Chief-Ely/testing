// lib/audio_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles microphone input, PCM16 encoding, and WebSocket streaming
class AudioService {
  final String serverUrl;
  FlutterSoundRecorder? _recorder;
  WebSocketChannel? _channel;
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;

  AudioService(this.serverUrl);

  /// Initialize microphone permission and recorder
  Future<void> init() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception("Microphone permission not granted");
    }
  }

  /// Start recording and streaming PCM16 audio via WebSocket
  Future<void> startStreaming() async {
    if (_isRecording) return;
    _isRecording = true;

    // Connect to FastAPI WebSocket endpoint
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    print("[Flutter] Connected to WebSocket: $serverUrl");

    // Create audio stream controller for Uint8List PCM16 chunks
    _audioStreamController = StreamController<Uint8List>();

    // Listen to captured audio frames
    _audioStreamController!.stream.listen((data) {
      if (!_isRecording || _channel == null) return;
      _channel!.sink.add(data); // send raw PCM16 bytes directly
    });

    // Start recording with correct, non-deprecated API
    await _recorder!.startRecorder(
      toStream: _audioStreamController!.sink,
      codec: Codec.pcm16,        // PCM16 format (matches backend)
      sampleRate: 16000,         // 16 kHz sample rate
      numChannels: 1,            // mono audio
      bitRate: 256000,           // optional, for consistent buffer size
    );

    // Listen for server messages (optional logging)
    _channel!.stream.listen(
      (event) => print("[Server] $event"),
      onDone: () {
        print("[Flutter] WebSocket closed by server.");
        _isRecording = false;
      },
      onError: (err) {
        print("[Flutter] WebSocket error: $err");
      },
    );
  }

  /// Stop the recording and close connections
  Future<void> stopStreaming() async {
    if (!_isRecording) return;
    _isRecording = false;

    await _recorder!.stopRecorder();
    await _audioStreamController?.close();
    await _channel?.sink.close();

    print("[Flutter] Stopped recording and closed WebSocket.");
  }

  /// Clean up recorder resources
  Future<void> dispose() async {
    await _recorder?.closeRecorder();
    _recorder = null;
  }
}
