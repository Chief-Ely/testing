// lib/services/audio_ws_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

typedef TranscriptCallback = void Function(String text);

class AudioWsService {
  // singleton
  AudioWsService._internal();
  static final AudioWsService _instance = AudioWsService._internal();
  factory AudioWsService() => _instance;

  // Public settings (tweak as needed)
  final int chunkSeconds = 3;    // seconds per chunk
  final double overlapSeconds = 0.5; // overlap in seconds to prepend from previous chunk
  final int sampleRate = 16000;  // whisper expects 16k
  final Codec _codec = Codec.pcm16WAV;

  // Runtime variables
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _wsUrl; // e.g. wss://xyz.ngrok.io/ws/transcribe
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  // temp file handling
  String? _lastChunkPath; // previous chunk file path (for overlap)
  Directory? _tmpDir;

  // callbacks
  TranscriptCallback? onTranscript; // UI -> set to update text
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  Function(String)? onError;

  // internal
  final Uuid _uuid = Uuid();

  // Future<void> init({required String wsUrl}) async {
  //   _wsUrl = wsUrl;
  //   _tmpDir ??= await getTemporaryDirectory();

  //   // init recorder
  //   _recorder ??= FlutterSoundRecorder();
  //   if (!await _recorder!.isInitialized()) {
  //     await _recorder!.openRecorder();
  //   }

  //   // request permissions
  //   await _requestPermissions();
  // }
  Future<void> init({required String wsUrl}) async {
    _wsUrl = wsUrl;
    _tmpDir ??= await getTemporaryDirectory();

    // create recorder instance if not created yet
    _recorder ??= FlutterSoundRecorder();

    // request permissions first (microphone + storage)
    await _requestPermissions();

    // Try to open the recorder; if already open, ignore the error.
    try {
      await _recorder!.openRecorder();
      // Optionally set subscription duration or audio session category here:
      // await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 50));
    } catch (e) {
      // If openRecorder throws because it's already open, ignore it.
      // Log for debug so you can inspect unexpected errors:
      debugPrint('openRecorder() warning/exception: $e');
    }
  }


  Future<void> connectWebSocket() async {
    if (_channel != null) return; // already connected
    if (_wsUrl == null) throw Exception("WebSocket URL not set. Call init(wsUrl:...) first.");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      _wsSub = _channel!.stream.listen((message) {
        // server sends text strings for each chunk
        if (onTranscript != null && message is String) {
          onTranscript!(message);
        }
      }, onError: (e) {
        if (onError != null) onError!(e.toString());
      }, onDone: () {
        disconnectWebSocket();
      });

      if (onConnected != null) onConnected!();
    } catch (e) {
      if (onError != null) onError!(e.toString());
      rethrow;
    }
  }

  Future<void> disconnectWebSocket() async {
    try {
      await _wsSub?.cancel();
      await _channel?.sink.close();
    } catch (_) {}
    _wsSub = null;
    _channel = null;
    if (onDisconnected != null) onDisconnected!();
  }

  Future<void> startRecordingAndStreaming() async {
    if (_isRecording) return;
    if (_channel == null) throw Exception("WebSocket not connected. Call connectWebSocket()");
    if (_recorder == null) throw Exception("Recorder not initialized. Call init() first.");

    _isRecording = true;
    _lastChunkPath = null;

    // Loop: create successive chunk files of length chunkSeconds seconds
    // We record to sequential files: fileA.wav (3s), stop, send, start fileB.wav, ...
    Future<void> loop() async {
      while (_isRecording) {
        final fname = "chunk_${_uuid.v4()}.wav";
        final fpath = '${_tmpDir!.path}/$fname';

        // start recorder to file (pcm16 WAV)
        await _recorder!.startRecorder(
          toFile: fpath,
          codec: _codec,
          sampleRate: sampleRate,
          numChannels: 1,
        );

        // wait chunk duration
        await Future.delayed(Duration(seconds: chunkSeconds));

        // stop recording
        await _recorder!.stopRecorder();

        // send (with overlap) - non-blocking
        _sendChunkWithOverlap(fpath);

        // small tiny delay to allow immediate restart (helps on some devices)
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    loop();
  }

  Future<void> stopRecordingAndStreaming() async {
    _isRecording = false;
    // ensure recorder stopped
    try {
      if (_recorder != null && await _recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
    } catch (_) {}
    // flush last chunk: send any leftover but we've been sending after each file already
  }

  // combine tail of previous file with current file, send bytes to server
  Future<void> _sendChunkWithOverlap(String currentPath) async {
    try {
      final currentBytes = await File(currentPath).readAsBytes();

      // Determine number of bytes for overlap (approx): overlapSeconds * sampleRate * bytesPerSample (2) * channels
      final int bytesPerSample = 2; // int16
      final int overlapBytesCount = (overlapSeconds * sampleRate * bytesPerSample).toInt();

      Uint8List payloadBytes;

      if (_lastChunkPath != null && await File(_lastChunkPath!).exists()) {
        final prevBytes = await File(_lastChunkPath!).readAsBytes();

        // WAV files have headers. We need raw PCM tails. We'll strip WAV headers.
        // Simplest approach: remove the first 44 bytes WAV header (standard) if present.
        // This is not 100% robust for all WAV variants but works for FlutterSound default PCM16 WAV.
        Uint8List prevRaw = _stripWavHeader(prevBytes);
        Uint8List currRaw = _stripWavHeader(currentBytes);

        final int take = overlapBytesCount <= prevRaw.length ? overlapBytesCount : prevRaw.length;
        final Uint8List overlapTail = prevRaw.sublist(prevRaw.length - take);

        // Compose: overlapTail + currRaw -> then rewrap as WAV bytes before sending
        final combinedRaw = Uint8List(overlapTail.length + currRaw.length);
        combinedRaw.setRange(0, overlapTail.length, overlapTail);
        combinedRaw.setRange(overlapTail.length, overlapTail.length + currRaw.length, currRaw);

        // Wrap into WAV container (PCM16) - create minimal header
        payloadBytes = _buildWavFromPcm16(combinedRaw, sampleRate, 1);

      } else {
        // No previous chunk -> send current as-is
        payloadBytes = currentBytes;
      }

      // send bytes to websocket
      _channel!.sink.add(payloadBytes);

      // update lastChunk
      // we keep the previous file path to allow reuse for next overlap
      // Optionally remove old files to save space
      if (_lastChunkPath != null) {
        try {
          await File(_lastChunkPath!).delete();
        } catch (_) {}
      }
      _lastChunkPath = currentPath;
    } catch (e) {
      if (onError != null) onError!(e.toString());
    }
  }

  // helper to strip standard 44-byte WAV header if present
  Uint8List _stripWavHeader(Uint8List wavBytes) {
    if (wavBytes.length > 44) {
      // check "RIFF" and "WAVE" bytes in header
      if (wavBytes[0] == 0x52 && wavBytes[1] == 0x49 && wavBytes[2] == 0x46 && wavBytes[3] == 0x46) {
        return wavBytes.sublist(44);
      }
    }
    return wavBytes;
  }

  // build WAV bytes from raw PCM16 little endian bytes
  Uint8List _buildWavFromPcm16(Uint8List pcm16, int sampleRate, int channels) {
    final int byteRate = sampleRate * channels * 2;
    final int blockAlign = channels * 2;
    final int dataSize = pcm16.length;
    final int chunkSize = 36 + dataSize;

    final header = BytesBuilder();
    header.add(_stringToBytes('RIFF'));
    header.add(_intToBytes(chunkSize, 4));
    header.add(_stringToBytes('WAVE'));
    header.add(_stringToBytes('fmt '));
    header.add(_intToBytes(16, 4)); // subchunk1 size
    header.add(_intToBytes(1, 2)); // audio format pcm = 1
    header.add(_intToBytes(channels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(16, 2)); // bits per sample
    header.add(_stringToBytes('data'));
    header.add(_intToBytes(dataSize, 4));
    header.add(pcm16);
    return header.toBytes();
  }

  List<int> _intToBytes(int value, int byteCount) {
    final bytes = List<int>.filled(byteCount, 0);
    for (int i = 0; i < byteCount; i++) {
      bytes[i] = (value >> (8 * i)) & 0xFF;
    }
    return bytes;
  }

  List<int> _stringToBytes(String s) => s.codeUnits;

  Future<void> dispose() async {
    await stopRecordingAndStreaming();
    await disconnectWebSocket();
    try {
      await _recorder?.closeRecorder();
    } catch (_) {}
    _recorder = null;
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }
}
