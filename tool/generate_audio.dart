import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

Uint8List createWav(List<double> samples, {int sampleRate = 22050}) {
  final byteCount = samples.length * 2;
  final buffer = ByteData(44 + byteCount);

  buffer.setUint8(0, 0x52); // R
  buffer.setUint8(1, 0x49); // I
  buffer.setUint8(2, 0x46); // F
  buffer.setUint8(3, 0x46); // F
  buffer.setUint32(4, 36 + byteCount, Endian.little);
  buffer.setUint8(8, 0x57); // W
  buffer.setUint8(9, 0x41); // A
  buffer.setUint8(10, 0x56); // V
  buffer.setUint8(11, 0x45); // E

  buffer.setUint8(12, 0x66); // f
  buffer.setUint8(13, 0x6D); // m
  buffer.setUint8(14, 0x74); // t
  buffer.setUint8(15, 0x20); // ' '
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);

  buffer.setUint8(36, 0x64); // d
  buffer.setUint8(37, 0x61); // a
  buffer.setUint8(38, 0x74); // t
  buffer.setUint8(39, 0x61); // a
  buffer.setUint32(40, byteCount, Endian.little);

  int offset = 44;
  for (final sample in samples) {
    final clamped = sample.clamp(-1.0, 1.0);
    buffer.setInt16(offset, (clamped * 32767.0).round(), Endian.little);
    offset += 2;
  }
  return buffer.buffer.asUint8List();
}

List<double> generateTap({int sr = 22050}) {
  final n = (0.055 * sr).toInt();
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final p = i / n;
    final env = math.exp(-p * 14.0);
    final freq = 720.0 - 460.0 * p;
    out.add(math.sin(2 * math.pi * freq * t) * env * 0.55);
  }
  return out;
}

List<double> generatePickup({int sr = 22050}) {
  final n = (0.18 * sr).toInt();
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final p = i / n;
    final env = p < 0.1 ? p / 0.1 : math.exp(-(p - 0.1) * 5.5);
    final freq = p < 0.45 ? 587.33 : 880.0; // D5 -> A5 cheerful fruit pop
    final wave = math.sin(2 * math.pi * freq * t) +
        0.25 * math.sin(4 * math.pi * freq * t);
    out.add(wave * env * 0.55);
  }
  return out;
}

List<double> generateWarning({int sr = 22050}) {
  final n = (0.20 * sr).toInt();
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final p = i / n;
    final pulse = (p < 0.42 || (p > 0.54 && p < 0.94)) ? 1.0 : 0.0;
    final freq = p < 0.5 ? 660.0 : 880.0;
    final wave = math.sin(2 * math.pi * freq * t);
    out.add(wave * pulse * 0.42);
  }
  return out;
}

List<double> generateBite({int sr = 22050}) {
  final n = (0.22 * sr).toInt();
  final rnd = math.Random(77);
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final p = i / n;
    // Double crunch envelope
    final env = (math.exp(-p * 12.0) + 0.65 * math.exp(-((p - 0.35).abs()) * 22.0))
        .clamp(0.0, 1.0);
    final freq = 210.0 - 115.0 * p;
    final tone = math.sin(2 * math.pi * freq * t);
    final crunch = (rnd.nextDouble() * 2 - 1) * 0.45;
    out.add((tone * 0.65 + crunch) * env * 0.65);
  }
  return out;
}

List<double> generateDeliver({int sr = 22050}) {
  final n = (0.30 * sr).toInt();
  final notes = [523.25, 659.25, 783.99]; // C5 - E5 - G5 warm triad
  final noteDur = 0.30 / notes.length;
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final idx = (t / noteDur).floor().clamp(0, notes.length - 1);
    final localP = (t - idx * noteDur) / noteDur;
    final env = math.exp(-localP * 4.5);
    final f = notes[idx];
    final wave = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t);
    out.add(wave * env * 0.5);
  }
  return out;
}

List<double> generateTruck({int sr = 22050}) {
  final n = (0.55 * sr).toInt();
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final p = i / n;
    // Warm miniature engine rev + cheerful beep-beep horn
    final engineFreq = 85.0 + 60.0 * p;
    final engine = math.sin(2 * math.pi * engineFreq * t) * 0.25 +
        math.sin(4 * math.pi * engineFreq * t) * 0.12;
    double horn = 0.0;
    if ((p > 0.12 && p < 0.26) || (p > 0.32 && p < 0.48)) {
      horn = (math.sin(2 * math.pi * 440.0 * t) +
              0.5 * math.sin(2 * math.pi * 554.37 * t)) *
          0.32;
    }
    final env = (1.0 - p * 0.6).clamp(0.0, 1.0);
    out.add((engine + horn) * env);
  }
  return out;
}

List<double> generateWin({int sr = 22050}) {
  final n = (0.60 * sr).toInt();
  final notes = [523.25, 659.25, 783.99, 1046.50, 1318.51];
  final noteDur = 0.60 / notes.length;
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final idx = (t / noteDur).floor().clamp(0, notes.length - 1);
    final localP = (t - idx * noteDur) / noteDur;
    final env = math.exp(-localP * 3.8);
    final f = notes[idx];
    final wave = math.sin(2 * math.pi * f * t) +
        0.3 * math.sin(4 * math.pi * f * t);
    out.add(wave * env * 0.45);
  }
  return out;
}

List<double> generateDefeat({int sr = 22050}) {
  final n = (0.48 * sr).toInt();
  final notes = [392.0, 349.23, 311.13, 261.63]; // G4 -> F4 -> Eb4 -> C4
  final noteDur = 0.48 / notes.length;
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final idx = (t / noteDur).floor().clamp(0, notes.length - 1);
    final localP = (t - idx * noteDur) / noteDur;
    final env = math.exp(-localP * 3.5);
    final f = notes[idx];
    out.add(math.sin(2 * math.pi * f * t) * env * 0.45);
  }
  return out;
}

List<double> generateTick({int sr = 22050}) {
  final n = (0.045 * sr).toInt();
  final out = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sr;
    final p = i / n;
    final env = math.exp(-p * 18.0);
    out.add(math.sin(2 * math.pi * 1050.0 * t) * env * 0.35);
  }
  return out;
}

/// Cheerful, gentle 6.4-second looping marimba adventure melody for background music.
List<double> generateBgm({int sr = 22050}) {
  const bpm = 112.5; // 0.266s per eighth note -> 24 steps = 6.4s loop
  const stepSec = 60.0 / bpm / 2.0;
  final melody = [
    523.25, 0.0, 659.25, 783.99, 659.25, 0.0, 587.33, 659.25,
    523.25, 0.0, 440.00, 523.25, 587.33, 0.0, 0.0, 0.0,
    659.25, 0.0, 783.99, 880.00, 783.99, 0.0, 659.25, 587.33,
  ];
  final bass = [
    130.81, 130.81, 196.00, 196.00, 174.61, 174.61, 196.00, 196.00,
    130.81, 130.81, 110.00, 110.00, 146.83, 146.83, 196.00, 196.00,
    130.81, 130.81, 196.00, 196.00, 174.61, 174.61, 196.00, 196.00,
  ];

  final totalSec = melody.length * stepSec;
  final totalSamples = (totalSec * sr).toInt();
  final out = <double>[];

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sr;
    final stepIdx = (t / stepSec).floor().clamp(0, melody.length - 1);
    final stepP = (t - stepIdx * stepSec) / stepSec;
    final mFreq = melody[stepIdx];
    final bFreq = bass[stepIdx];

    double mWave = 0.0;
    if (mFreq > 0) {
      final mEnv = math.exp(-stepP * 5.2);
      mWave = (math.sin(2 * math.pi * mFreq * t) +
              0.2 * math.sin(4 * math.pi * mFreq * t)) *
          mEnv *
          0.16;
    }

    final bEnv = math.exp(-stepP * 3.2);
    final bWave = math.sin(2 * math.pi * bFreq * t) * bEnv * 0.11;

    out.add(mWave + bWave);
  }
  return out;
}

void main() {
  final dir = Directory('assets/audio');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final files = <String, List<double>>{
    'tap.wav': generateTap(),
    'pickup.wav': generatePickup(),
    'warning.wav': generateWarning(),
    'bite.wav': generateBite(),
    'deliver.wav': generateDeliver(),
    'truck.wav': generateTruck(),
    'win.wav': generateWin(),
    'defeat.wav': generateDefeat(),
    'tick.wav': generateTick(),
    'bgm.wav': generateBgm(),
  };

  for (final entry in files.entries) {
    final f = File('assets/audio/${entry.key}');
    f.writeAsBytesSync(createWav(entry.value));
    print('Generated ${f.path} (${f.lengthSync()} bytes)');
  }
}
