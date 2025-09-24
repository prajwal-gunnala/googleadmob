import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:io';
import '../../../core/models/photo_model.dart';
import '../../../core/services/photo_service.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;
  final VoidCallback onPhotoDeleted;

  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onPhotoDeleted,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final PhotoService _photoService = PhotoService();
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PhotoModel get _currentPhoto => widget.photos[_currentIndex];

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
      final success = await _photoService.saveToGallery(_currentPhoto);
      if (success) {
        _showSnackBar('Photo saved to gallery!', Colors.green);
      } else {
        _showSnackBar('Failed to save photo', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isActionInProgress = false;
      });
    }
  }

  Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo? This action cannot be undone.'),
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
        final success = await _photoService.deletePhoto(_currentPhoto);
        if (success) {
          widget.onPhotoDeleted();
          if (mounted) {
            Navigator.of(context).pop();
            _showSnackBar('Photo deleted successfully', Colors.orange);
          }
        } else {
          _showSnackBar('Failed to delete photo', Colors.red);
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

  void _showPhotoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('File Name', _currentPhoto.fileName),
            _buildInfoRow('Date Taken', _formatDate(_currentPhoto.uploadDate)),
            _buildInfoRow('File Size', _currentPhoto.fileSizeFormatted),
            _buildInfoRow('Resolution', 'Available in full view'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} of ${widget.photos.length}'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showPhotoInfo,
            icon: const Icon(Icons.info_outline),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _saveToGallery();
                  break;
                case 'delete':
                  _deletePhoto();
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
          // Photo gallery
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (context, index) {
              final photo = widget.photos[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(photo.originalPath)),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2.0,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            itemCount: widget.photos.length,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  backgroundColor: Colors.grey,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
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
                onPressed: _showPhotoInfo,
                icon: const Icon(Icons.info_outline, color: Colors.white),
                tooltip: 'Photo Info',
              ),
              IconButton(
                onPressed: _isActionInProgress ? null : _deletePhoto,
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Photo',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
