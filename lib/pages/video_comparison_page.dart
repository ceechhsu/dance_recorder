import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/audio_sync.dart';

class VideoComparisonPage extends StatefulWidget {
  final File userVideo;
  final String referenceVideoAsset;

  const VideoComparisonPage({
    Key? key,
    required this.userVideo,
    required this.referenceVideoAsset,
  }) : super(key: key);

  @override
  _VideoComparisonPageState createState() => _VideoComparisonPageState();
}

class _VideoComparisonPageState extends State<VideoComparisonPage> {
  late VideoPlayerController _userController;
  late VideoPlayerController _refController;
  List<double>? _userWaveform;
  List<double>? _refWaveform;
  double _refOpacity = 0.5;
  bool _isInitialized = false;
  bool _hasSynced = false;

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    // Initialize video controllers
    _userController = VideoPlayerController.file(
      widget.userVideo,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _refController = VideoPlayerController.asset(
      widget.referenceVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await Future.wait([
      _userController.initialize(),
      _refController.initialize(),
    ]);

    // Extract audio and load waveforms
    final userAudio = await AudioSync.extractAudio(
      widget.userVideo.path,
      'user_audio',
    );
    final tempDir = await getTemporaryDirectory();
    final refTempPath = '${tempDir.path}/ref_video.mp4';
    final byteData = await rootBundle.load(widget.referenceVideoAsset);
    await File(refTempPath).writeAsBytes(byteData.buffer.asUint8List());
    final refAudio = await AudioSync.extractAudio(refTempPath, 'ref_audio');

    final userWave = await AudioSync.loadWaveform(userAudio, bucketCount: 1024);
    final refWave = await AudioSync.loadWaveform(refAudio, bucketCount: 1024);

    setState(() {
      _userWaveform = userWave;
      _refWaveform = refWave;
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_userController.value.isPlaying && _refController.value.isPlaying) {
      await _userController.pause();
      await _refController.pause();
    } else {
      if (!_hasSynced) {
        final userAudio = await AudioSync.extractAudio(
          widget.userVideo.path,
          'user_audio',
        );
        final tempDir = await getTemporaryDirectory();
        final refTempPath = '${tempDir.path}/ref_video.mp4';
        final byteData = await rootBundle.load(widget.referenceVideoAsset);
        await File(refTempPath).writeAsBytes(byteData.buffer.asUint8List());
        final refAudio = await AudioSync.extractAudio(refTempPath, 'ref_audio');
        final userBeat = await AudioSync.detectFirstBeat(userAudio);
        final refBeat = await AudioSync.detectFirstBeat(refAudio);
        await Future.wait([
          _userController.seekTo(userBeat),
          _refController.seekTo(refBeat),
        ]);
        _hasSynced = true;
      }
      await Future.wait([_userController.play(), _refController.play()]);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _userWaveform == null || _refWaveform == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Video Comparison')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Video Comparison')),
      body: Column(
        children: [
          // VIDEO DISPLAY: preserve both aspect ratios without stretching
          AspectRatio(
            aspectRatio: _userController.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_userController),
                Opacity(
                  opacity: _refOpacity,
                  child: AspectRatio(
                    aspectRatio: _refController.value.aspectRatio,
                    child: VideoPlayer(_refController),
                  ),
                ),
              ],
            ),
          ),

          // CONTROLS
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    (_userController.value.isPlaying &&
                            _refController.value.isPlaying)
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: _togglePlayPause,
                ),
                const SizedBox(height: 16),
                const Text('Reference Video Transparency'),
                Slider(
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  value: _refOpacity,
                  label: '\${(_refOpacity * 100).round()}%',
                  onChanged: (v) => setState(() => _refOpacity = v),
                ),
              ],
            ),
          ),

          // WAVEFORMS
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _WaveformPainter(_userWaveform!, Colors.blue),
              size: Size.infinite,
            ),
          ),
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _WaveformPainter(_refWaveform!, Colors.red),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  _WaveformPainter(this.waveform, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeWidth = 1
          ..color = color;
    final midY = size.height / 2;
    final dx = size.width / waveform.length;
    for (int i = 0; i < waveform.length; i++) {
      final x = i * dx;
      final y = waveform[i] * midY;
      canvas.drawLine(Offset(x, midY - y), Offset(x, midY + y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => false;
}
