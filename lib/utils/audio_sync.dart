import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
  /// Scans 16-bit PCM samples for amplitude above 20% of the max,
  /// starting immediately after the WAV header.
  static Future<Duration> detectFirstBeat(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    const headerSize = 44;
    const sampleRate = 44100;
    if (bytes.lengthInBytes <= headerSize + 1) {
      return Duration.zero;
    }

    // 1) Find the maximum amplitude to set a dynamic threshold.
    int maxAmp = 0;
    for (int i = headerSize; i + 1 < bytes.lengthInBytes; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample & 0x8000 != 0) sample = sample - 0x10000;
      maxAmp = max(maxAmp, sample.abs());
    }
    final threshold = (maxAmp * 0.2).round(); // 20% of peak

    // Start scanning immediately after the WAV header
    final skipBytes = headerSize;

    // 2) Scan for the first sample above threshold.
    for (int i = skipBytes; i + 1 < bytes.lengthInBytes; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample & 0x8000 != 0) sample = sample - 0x10000;
      if (sample.abs() > threshold) {
        int sampleIndex = (i - headerSize) ~/ 2;
        double seconds = sampleIndex / sampleRate;
        return Duration(milliseconds: (seconds * 1000).round());
      }
    }

    // If no beat found, return zero
    return Duration.zero;
  }
}
