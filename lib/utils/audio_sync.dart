import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class AudioSync {
  /// Extracts the audio track from the given video file and saves it as a WAV file.
  static Future<File> extractAudio(
    String videoPath,
    String outputFilename,
  ) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/$outputFilename.wav';
    final command = '-i "$videoPath" -ac 1 -ar 44100 -vn "$outputPath"';
    await FFmpegKit.execute(command);
    return File(outputPath);
  }

  /// Detects the first significant beat in the audio file.
  /// Scans 16-bit PCM samples for amplitude above 5% of the max (min 500),
  /// starting immediately after the WAV header.
  static Future<Duration> detectFirstBeat(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    const headerSize = 44;
    const sampleRate = 44100;
    if (bytes.lengthInBytes <= headerSize + 1) {
      return Duration.zero;
    }

    // 1) Find the maximum amplitude
    int maxAmp = 0;
    for (int i = headerSize; i + 1 < bytes.lengthInBytes; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample & 0x8000 != 0) sample -= 0x10000;
      maxAmp = max(maxAmp, sample.abs());
    }

    // 2) Threshold = max(5% of peak, 500)
    final dynamicThreshold = (maxAmp * 0.05).round();
    final threshold = max(dynamicThreshold, 500);

    // 3) Scan for first sample above threshold
    for (int i = headerSize; i + 1 < bytes.lengthInBytes; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample & 0x8000 != 0) sample -= 0x10000;
      if (sample.abs() > threshold) {
        int sampleIndex = (i - headerSize) ~/ 2;
        double seconds = sampleIndex / sampleRate;
        return Duration(milliseconds: (seconds * 1000).round());
      }
    }

    return Duration.zero;
  }

  /// Loads the waveform amplitudes (normalized 0.0–1.0) from a WAV file.
  /// Returns a list of doubles, one per sample, normalized by the peak amplitude.
  static Future<List<double>> loadWaveform(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    const headerSize = 44;
    if (bytes.lengthInBytes <= headerSize + 1) {
      return [];
    }

    // 1) Read all samples and find peak
    final samples = <int>[];
    int maxAmp = 0;
    for (int i = headerSize; i + 1 < bytes.lengthInBytes; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample & 0x8000 != 0) sample -= 0x10000;
      samples.add(sample);
      maxAmp = max(maxAmp, sample.abs());
    }
    if (maxAmp == 0) maxAmp = 1;

    // 2) Normalize to 0.0–1.0
    return samples.map((s) => s.abs() / maxAmp).toList();
  }
}
