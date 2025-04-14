import 'dart:io';
import 'dart:convert'; // For JSON decoding
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'video_comparison_page.dart';

class VideoSelectionPage extends StatefulWidget {
  const VideoSelectionPage({super.key});

  @override
  _VideoSelectionPageState createState() => _VideoSelectionPageState();
}

class _VideoSelectionPageState extends State<VideoSelectionPage> {
  File? userVideo;
  final ImagePicker picker = ImagePicker();
  String? _selectedReferenceVideo;

  // Loads all asset video files from the assets/videos directory.
  Future<List<String>> loadReferenceVideos() async {
    String manifestContent = await DefaultAssetBundle.of(
      context,
    ).loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    // Filter keys that start with assets/videos/ and end with .mp4
    return manifestMap.keys
        .where(
          (String key) =>
              key.startsWith('assets/videos/') && key.endsWith('.mp4'),
        )
        .toList();
  }

  // Picks the user's video from the gallery.
  Future<void> pickUserVideo() async {
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        userVideo = File(pickedFile.path);
      });
    }
  }

  // Navigates to the comparison page after checking that both selections are made.
  void navigateToComparison() {
    if (userVideo != null && _selectedReferenceVideo != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => VideoComparisonPage(
                userVideo: userVideo!,
                referenceVideoAsset: _selectedReferenceVideo!,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your video and a reference video from the list.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Videos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickUserVideo,
              child: Text(
                userVideo == null ? 'Select Your Video' : 'User Video Selected',
              ),
            ),
            const SizedBox(height: 20),
            const Text('Select a Reference Video from Bundled Assets:'),
            // Use FutureBuilder to load and display the list of reference videos.
            FutureBuilder<List<String>>(
              future: loadReferenceVideos(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final videoList = snapshot.data!;
                return Expanded(
                  child: ListView.builder(
                    itemCount: videoList.length,
                    itemBuilder: (context, index) {
                      String videoPath = videoList[index];
                      String fileName = videoPath.split('/').last;
                      bool isSelected = _selectedReferenceVideo == videoPath;
                      return ListTile(
                        title: Text(fileName),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedReferenceVideo = videoPath;
                          });
                        },
                      );
                    },
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: navigateToComparison,
              child: const Text('Compare Videos'),
            ),
          ],
        ),
      ),
    );
  }
}
