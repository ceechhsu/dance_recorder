import 'package:flutter/material.dart';
import 'pages/video_selection_page.dart'; // <-- NEW: Import the VideoSelectionPage

void main() {
  runApp(const DanceRecorderApp());
}

class DanceRecorderApp extends StatelessWidget {
  const DanceRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dance Recorder', // Updated app title
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          const VideoSelectionPage(), // <-- Updated: Start with the VideoSelectionPage
    );
  }
}
