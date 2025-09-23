import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/video_model.dart';
import '../services/video_service.dart';

class VideoTrimPage extends StatefulWidget {
  final VideoModel video;
  final VoidCallback onVideoTrimmed;

  const VideoTrimPage({
    super.key,
    required this.video,
    required this.onVideoTrimmed,
  });

  @override
  State<VideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<VideoTrimPage> {
  final VideoService _videoService = VideoService();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.video.originalPath));
    
    try {
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
        _endTime = _controller!.value.duration;
      });
      
      // Listen to position changes
      _controller!.addListener(() {
        if (mounted) {
          setState(() {
            _currentPosition = _controller!.value.position;
          });
        }
      });
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  Future<void> _trimVideo() async {
    if (_controller == null || !_isInitialized) return;
    
    if (_endTime <= _startTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be greater than start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final trimmedVideo = await _videoService.trimVideo(widget.video, _startTime, _endTime);
      
      if (trimmedVideo != null) {
        widget.onVideoTrimmed();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video trimmed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to trim video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error trimming video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _seekTo(Duration position) {
    if (_controller != null && _isInitialized) {
      _controller!.seekTo(position);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Trim Video'),
        centerTitle: true,
        actions: [
          if (!_isProcessing && _isInitialized)
            TextButton(
              onPressed: _trimVideo,
              child: const Text(
                'Trim',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Trimming video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : !_isInitialized
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  children: [
                    // Video player
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),
                    
                    // Controls
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: Colors.grey.shade900,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Play/Pause button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_controller!.value.isPlaying) {
                                        _controller!.pause();
                                      } else {
                                        _controller!.play();
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Progress bar
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_currentPosition),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _currentPosition.inMilliseconds.toDouble(),
                                    max: _controller!.value.duration.inMilliseconds.toDouble(),
                                    onChanged: (value) {
                                      final position = Duration(milliseconds: value.toInt());
                                      _seekTo(position);
                                    },
                                  ),
                                ),
                                Text(
                                  _formatDuration(_controller!.value.duration),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Trim controls
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Start Time',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      Text(
                                        _formatDuration(_startTime),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _startTime = _currentPosition;
                                          });
                                        },
                                        child: const Text('Set Start'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'End Time',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      Text(
                                        _formatDuration(_endTime),
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _endTime = _currentPosition;
                                          });
                                        },
                                        child: const Text('Set End'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Trim info
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Trimmed Duration: ${_formatDuration(_endTime - _startTime)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Original: ${widget.video.durationFormatted}',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
