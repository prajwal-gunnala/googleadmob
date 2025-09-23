import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/video_model.dart';
import '../services/video_service.dart';
import 'video_trim_page.dart';

class VideoViewerPage extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  final VoidCallback onVideoDeleted;

  const VideoViewerPage({
    super.key,
    required this.videos,
    required this.initialIndex,
    required this.onVideoDeleted,
  });

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final VideoService _videoService = VideoService();
  bool _isActionInProgress = false;
  
  Map<int, VideoPlayerController?> _controllers = {};
  Map<int, bool> _initialized = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeCurrentVideo();
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (final controller in _controllers.values) {
      controller?.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  VideoModel get _currentVideo => widget.videos[_currentIndex];

  Future<void> _initializeCurrentVideo() async {
    final controller = VideoPlayerController.file(File(_currentVideo.originalPath));
    _controllers[_currentIndex] = controller;
    _initialized[_currentIndex] = false;
    
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _initialized[_currentIndex] = true;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    if (_isActionInProgress) return;
    
    setState(() {
      _isActionInProgress = true;
    });

    try {
      final success = await _videoService.saveToGallery(_currentVideo);
      if (success) {
        _showSnackBar('Video saved to gallery!', Colors.green);
      } else {
        _showSnackBar('Failed to save video', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isActionInProgress = false;
      });
    }
  }

  Future<void> _deleteVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_isActionInProgress) return;
      
      setState(() {
        _isActionInProgress = true;
      });

      try {
        final success = await _videoService.deleteVideo(_currentVideo);
        if (success) {
          widget.onVideoDeleted();
          if (mounted) {
            Navigator.of(context).pop();
            _showSnackBar('Video deleted successfully', Colors.orange);
          }
        } else {
          _showSnackBar('Failed to delete video', Colors.red);
        }
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      } finally {
        if (mounted) {
          setState(() {
            _isActionInProgress = false;
          });
        }
      }
    }
  }

  void _trimVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoTrimPage(
          video: _currentVideo,
          onVideoTrimmed: () {
            widget.onVideoDeleted(); // Refresh the video list
          },
        ),
      ),
    );
  }

  void _showVideoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('File Name', _currentVideo.fileName),
            _buildInfoRow('Date Added', _formatDate(_currentVideo.uploadDate)),
            _buildInfoRow('Duration', _currentVideo.durationFormatted),
            _buildInfoRow('File Size', _currentVideo.fileSizeFormatted),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller != null && _initialized[_currentIndex] == true) {
      setState(() {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} of ${widget.videos.length}'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showVideoInfo,
            icon: const Icon(Icons.info_outline),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _saveToGallery();
                  break;
                case 'trim':
                  _trimVideo();
                  break;
                case 'delete':
                  _deleteVideo();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Save to Gallery'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'trim',
                child: ListTile(
                  leading: Icon(Icons.content_cut),
                  title: Text('Trim Video'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Video player
          PageView.builder(
            controller: _pageController,
            itemCount: widget.videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _initializeCurrentVideo();
            },
            itemBuilder: (context, index) {
              final controller = _controllers[index];
              final isInitialized = _initialized[index] ?? false;
              
              return Center(
                child: isInitialized && controller != null
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
              );
            },
          ),
          
          // Play/Pause button overlay
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (_controllers[_currentIndex]?.value.isPlaying ?? false)
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isActionInProgress)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _isActionInProgress ? null : _saveToGallery,
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Save to Gallery',
              ),
              IconButton(
                onPressed: _trimVideo,
                icon: const Icon(Icons.content_cut, color: Colors.white),
                tooltip: 'Trim Video',
              ),
              IconButton(
                onPressed: _showVideoInfo,
                icon: const Icon(Icons.info_outline, color: Colors.white),
                tooltip: 'Video Info',
              ),
              IconButton(
                onPressed: _isActionInProgress ? null : _deleteVideo,
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Video',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
