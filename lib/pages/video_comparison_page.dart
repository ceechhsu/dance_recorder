import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  double _refOpacity = 0.5; // Start with 50% opacity

  @override
  void initState() {
    super.initState();
    // Initialize the user's video controller with mixing enabled.
    _userController = VideoPlayerController.file(
      widget.userVideo,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        setState(() {});
      });

    // Initialize the reference video controller from asset with mixing enabled.
    _refController = VideoPlayerController.asset(
      widget.referenceVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _userController.dispose();
    _refController.dispose();
    super.dispose();
  }

  // Toggle play/pause simultaneously for both videos.
  Future<void> togglePlayPause() async {
    // If either video is not playing, play both.
    if (!_userController.value.isPlaying || !_refController.value.isPlaying) {
      await Future.wait([
        _userController.play(),
        _refController.play(),
      ]);
    } else {
      // Otherwise, pause both.
      await Future.wait([
        _userController.pause(),
        _refController.pause(),
      ]);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Ensure both video controllers are initialized.
    if (!_userController.value.isInitialized || !_refController.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparing Videos')),
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
                // User's video.
                AspectRatio(
                  aspectRatio: _userController.value.aspectRatio,
                  child: VideoPlayer(_userController),
                ),
                // Overlay the reference video with adjustable opacity.
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // A single toggle button to play/pause both videos.
                IconButton(
                  icon: Icon(
                    (_userController.value.isPlaying && _refController.value.isPlaying)
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: togglePlayPause,
                ),
                const SizedBox(height: 16),
                const Text('Reference Video Transparency'),
                Slider(
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  value: _refOpacity,
                  label: '${(_refOpacity * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _refOpacity = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
