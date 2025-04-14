import 'dart:io';
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

  /// Detects the first significant beat in the audio file by scanning
  /// 16-bit PCM samples for amplitude above a threshold.
  /// Returns the Duration of the first detected beat.
  static Future<Duration> detectFirstBeat(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    // WAV header is 44 bytes; samples start after that
    const headerSize = 44;
    const sampleRate = 44100; // 44.1 kHz as set in extractAudio
    const threshold = 5000; // Amplitude threshold

    // Ensure file is large enough
    if (bytes.lengthInBytes <= headerSize + 1) {
      return Duration.zero;
    }

    // Iterate over samples (16-bit little endian)
    for (int i = headerSize; i + 1 < bytes.lengthInBytes; i += 2) {
      // Read two bytes as signed 16-bit
      int sample = bytes[i] | (bytes[i + 1] << 8);
      // Convert to signed
      if (sample & 0x8000 != 0) sample = sample - 0x10000;
      if (sample.abs() > threshold) {
        // Compute the time of this sample
        int sampleIndex = (i - headerSize) ~/ 2;
        double seconds = sampleIndex / sampleRate;
        return Duration(milliseconds: (seconds * 1000).round());
      }
    }

    // If no beat found, return zero
    return Duration.zero;
  }
}
