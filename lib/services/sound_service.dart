// lib/services/sound_service.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  static Uint8List? _successWav;
  static Uint8List? _errorWav;
  static Uint8List? _cashWav;

  /// Initializes the synthesized WAV audio buffers
  static void init() {
    _successWav ??= _generateToneWav(frequency: 2400, durationMs: 90);
    _errorWav ??= _generateDoubleToneWav(freq: 400, beepMs: 100, pauseMs: 40);
    _cashWav ??= _generateChimeWav([1000, 1500, 2000], durationPerNoteMs: 60);
  }

  /// Plays a high-pitched positive beep and triggers haptic vibration on successful barcode scan
  static Future<void> playSuccessBeep() async {
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      _successWav ??= _generateToneWav(frequency: 2400, durationMs: 90);
      await _player.stop();
      await _player.play(BytesSource(_successWav!));
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Plays a low-pitched double beep and triggers heavy haptic vibration on failed/unrecognized scan
  static Future<void> playErrorBeep() async {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);

      _errorWav ??= _generateDoubleToneWav(freq: 400, beepMs: 100, pauseMs: 40);
      await _player.stop();
      await _player.play(BytesSource(_errorWav!));
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Plays a register chime when an order checkout is completed
  static Future<void> playCashBeep() async {
    try {
      HapticFeedback.lightImpact();

      _cashWav ??= _generateChimeWav([1000, 1500, 2000], durationPerNoteMs: 60);
      await _player.stop();
      await _player.play(BytesSource(_cashWav!));
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }

  /// Generates a single PCM mono 8-bit WAV tone
  static Uint8List _generateToneWav({required double frequency, required int durationMs}) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * (durationMs / 1000)).toInt();
    final dataSize = numSamples;
    final fileSize = 44 + dataSize;

    final bytes = ByteData(fileSize);

    // RIFF Header
    _writeString(bytes, 0, 'RIFF');
    bytes.setUint32(4, fileSize - 8, Endian.little);
    _writeString(bytes, 8, 'WAVE');

    // "fmt " chunk
    _writeString(bytes, 12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // chunk size
    bytes.setUint16(20, 1, Endian.little); // Audio format 1 (PCM)
    bytes.setUint16(22, 1, Endian.little); // Num channels (Mono)
    bytes.setUint32(24, sampleRate, Endian.little); // Sample rate
    bytes.setUint32(28, sampleRate, Endian.little); // Byte rate (SampleRate * 1 * 1)
    bytes.setUint16(32, 1, Endian.little); // Block align
    bytes.setUint16(34, 8, Endian.little); // Bits per sample

    // "data" chunk
    _writeString(bytes, 36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    // Write sine wave samples with gentle attack and release
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final angle = 2 * pi * frequency * t;
      double envelope = 1.0;
      if (i < 50) envelope = i / 50.0;
      if (i > numSamples - 100) envelope = (numSamples - i) / 100.0;

      final sample = (128 + 120 * sin(angle) * envelope).toInt().clamp(0, 255);
      bytes.setUint8(44 + i, sample);
    }

    return bytes.buffer.asUint8List();
  }

  /// Generates a double-beep PCM WAV for error feedback
  static Uint8List _generateDoubleToneWav({required double freq, required int beepMs, required int pauseMs}) {
    const sampleRate = 22050;
    final beepSamples = (sampleRate * (beepMs / 1000)).toInt();
    final pauseSamples = (sampleRate * (pauseMs / 1000)).toInt();
    final totalSamples = (beepSamples * 2) + pauseSamples;
    final fileSize = 44 + totalSamples;

    final bytes = ByteData(fileSize);

    // RIFF Header
    _writeString(bytes, 0, 'RIFF');
    bytes.setUint32(4, fileSize - 8, Endian.little);
    _writeString(bytes, 8, 'WAVE');

    // "fmt " chunk
    _writeString(bytes, 12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate, Endian.little);
    bytes.setUint16(32, 1, Endian.little);
    bytes.setUint16(34, 8, Endian.little);

    // "data" chunk
    _writeString(bytes, 36, 'data');
    bytes.setUint32(40, totalSamples, Endian.little);

    int offset = 44;

    // Beep 1
    for (int i = 0; i < beepSamples; i++) {
      final t = i / sampleRate;
      final sample = (128 + 120 * sin(2 * pi * freq * t)).toInt().clamp(0, 255);
      bytes.setUint8(offset++, sample);
    }

    // Silence
    for (int i = 0; i < pauseSamples; i++) {
      bytes.setUint8(offset++, 128);
    }

    // Beep 2
    for (int i = 0; i < beepSamples; i++) {
      final t = i / sampleRate;
      final sample = (128 + 120 * sin(2 * pi * freq * t)).toInt().clamp(0, 255);
      bytes.setUint8(offset++, sample);
    }

    return bytes.buffer.asUint8List();
  }

  /// Generates a multi-frequency chime WAV
  static Uint8List _generateChimeWav(List<double> freqs, {required int durationPerNoteMs}) {
    const sampleRate = 22050;
    final noteSamples = (sampleRate * (durationPerNoteMs / 1000)).toInt();
    final totalSamples = noteSamples * freqs.length;
    final fileSize = 44 + totalSamples;

    final bytes = ByteData(fileSize);

    // Header
    _writeString(bytes, 0, 'RIFF');
    bytes.setUint32(4, fileSize - 8, Endian.little);
    _writeString(bytes, 8, 'WAVE');
    _writeString(bytes, 12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate, Endian.little);
    bytes.setUint16(32, 1, Endian.little);
    bytes.setUint16(34, 8, Endian.little);
    _writeString(bytes, 36, 'data');
    bytes.setUint32(40, totalSamples, Endian.little);

    int offset = 44;
    for (final freq in freqs) {
      for (int i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        final sample = (128 + 110 * sin(2 * pi * freq * t)).toInt().clamp(0, 255);
        bytes.setUint8(offset++, sample);
      }
    }

    return bytes.buffer.asUint8List();
  }

  static void _writeString(ByteData bytes, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
