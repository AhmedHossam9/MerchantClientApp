import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

class SlideshowBackground extends StatefulWidget {
  final List<String> imagePaths;
  final double blurAmount; // Adjust the blur intensity

  SlideshowBackground({required this.imagePaths, this.blurAmount = 5.0});

  @override
  _SlideshowBackgroundState createState() => _SlideshowBackgroundState();
}

class _SlideshowBackgroundState extends State<SlideshowBackground> {
  int _currentImageIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSlideshow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSlideshow() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % widget.imagePaths.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image with smooth transition
        AnimatedSwitcher(
          duration: Duration(seconds: 1),
          child: Image.asset(
            widget.imagePaths[_currentImageIndex],
            key: ValueKey<int>(_currentImageIndex),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Apply Blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blurAmount, sigmaY: widget.blurAmount),
          child: Container(color: Colors.black.withOpacity(0.3)), // Light overlay for readability
        ),
      ],
    );
  }
}
