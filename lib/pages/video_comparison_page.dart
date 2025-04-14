import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart'; // For getTemporaryDirectory
import '../utils/audio_sync.dart'; // Your helper

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
  double _refOpacity = 0.5;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
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

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _refController.dispose();
    super.dispose();
  }

  /// Toggles play/pause. On play, does audio‑sync then plays both.
  Future<void> _togglePlayPause() async {
    if (_userController.value.isPlaying && _refController.value.isPlaying) {
      // Pause both
      await _userController.pause();
      await _refController.pause();
    } else {
      // 1) Extract audio from user video
      final userAudio = await AudioSync.extractAudio(
        widget.userVideo.path,
        'user_audio',
      );

      // 2) Copy reference asset to temp file
      final tempDir = await getTemporaryDirectory();
      final refTempPath = '${tempDir.path}/ref_video.mp4';
      final byteData = await rootBundle.load(widget.referenceVideoAsset);
      await File(refTempPath).writeAsBytes(byteData.buffer.asUint8List());

      // 3) Extract audio from reference video
      final refAudio = await AudioSync.extractAudio(refTempPath, 'ref_audio');

      // 4) Detect first beat in each
      final userBeat = await AudioSync.detectFirstBeat(userAudio);
      final refBeat = await AudioSync.detectFirstBeat(refAudio);

      // 5) Seek both to beat positions
      await Future.wait([
        _userController.seekTo(userBeat),
        _refController.seekTo(refBeat),
      ]);

      // 6) Play both
      await Future.wait([_userController.play(), _refController.play()]);
    }

    setState(() {}); // Refresh icon
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Video Comparison')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Video Comparison')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _userController.value.aspectRatio,
                  child: VideoPlayer(_userController),
                ),
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
                  onPressed: _togglePlayPause, // Updated toggle logic
                ),
                const SizedBox(height: 16),
                const Text('Reference Video Transparency'),
                Slider(
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  value: _refOpacity,
                  label: '${(_refOpacity * 100).round()}%',
                  onChanged: (v) => setState(() => _refOpacity = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
