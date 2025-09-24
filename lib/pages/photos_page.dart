import 'package:flutter/material.dart';
import 'dart:io';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import 'photo_viewer_page.dart';

class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  final PhotoService _photoService = PhotoService();
  List<PhotoModel> _photos = [];
  bool _isLoading = true;
  Map<String, dynamic> _storageInfo = {};
  
  // Multi-selection state
  bool _isSelectionMode = false;
  Set<String> _selectedPhotoIds = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoadPhotos();
  }

  Future<void> _initializeAndLoadPhotos() async {
    try {
      await _photoService.initialize();
      await _loadPhotos();
    } catch (e) {
      print('Error initializing photos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _photoService.getPhotos();
      final storageInfo = await _photoService.getStorageInfo();
      
      setState(() {
        _photos = photos.reversed.toList(); // Show newest first
        _storageInfo = storageInfo;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading photos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final photo = await _photoService.pickFromCamera();
      if (photo != null) {
        await _loadPhotos();
        _showSnackBar('Photo captured successfully!', Colors.green);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to capture photo: $e', Colors.red);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final photo = await _photoService.pickFromGallery();
      if (photo != null) {
        await _loadPhotos();
        _showSnackBar('Photo added successfully!', Colors.green);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to add photo: $e', Colors.red);
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

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(PhotoModel photo, int index) {
    if (_isSelectionMode) {
      _toggleSelection(photo.id);
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerPage(
          photos: _photos,
          initialIndex: index,
          onPhotoDeleted: _loadPhotos,
        ),
      ),
    );
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  void _enterSelectionMode(String photoId) {
    setState(() {
      _isSelectionMode = true;
      _selectedPhotoIds.clear();
      _selectedPhotoIds.add(photoId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhotoIds.clear();
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    if (_selectedPhotoIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text('Are you sure you want to delete ${_selectedPhotoIds.length} photo(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final photosToDelete = _photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
        final success = await _photoService.deleteMultiplePhotos(photosToDelete);
        
        if (success) {
          await _loadPhotos();
          _exitSelectionMode();
          _showSnackBar('${photosToDelete.length} photo(s) deleted successfully', Colors.orange);
        } else {
          _showSnackBar('Failed to delete photos', Colors.red);
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createCollageFromSelected() async {
    if (_selectedPhotoIds.length != 2) {
      _showSnackBar('Please select exactly 2 photos for collage', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedPhotos = _photos.where((p) => _selectedPhotoIds.contains(p.id)).toList();
      final collagePhoto = await _photoService.createCollage(selectedPhotos[0], selectedPhotos[1]);
      
      if (collagePhoto != null) {
        await _loadPhotos();
        _exitSelectionMode();
        _showSnackBar('Collage created successfully!', Colors.green);
      } else {
        _showSnackBar('Failed to create collage', Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedPhotoIds.length} selected')
            : const Text('Photos'),
        centerTitle: true,
        leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Selected',
                  onPressed: _deleteSelectedPhotos,
                ),
              ]
            : [
                if (_storageInfo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        '${_storageInfo['photoCount']} • ${_storageInfo['totalSizeFormatted']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Text(
                  'Select two photos to make a collage.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading photos...'),
                          ],
                        ),
                      )
                    : _photos.isEmpty
                        ? _buildEmptyState()
                        : _buildPhotoGrid(),
              ),
            ],
          ),
          if (_isSelectionMode && _selectedPhotoIds.length == 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _createCollageFromSelected,
                  icon: const Icon(Icons.collections, color: Colors.white),
                  label: const Text('Make Collage', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode 
          ? null 
          : FloatingActionButton(
              onPressed: _showUploadOptions,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_a_photo, color: Colors.white),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Photos Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first photo',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showUploadOptions,
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            label: const Text('Add Photo', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final photo = _photos[index];
          return _buildPhotoItem(photo, index);
        },
      ),
    );
  }

  Widget _buildPhotoItem(PhotoModel photo, int index) {
    final isSelected = _selectedPhotoIds.contains(photo.id);
    
    return GestureDetector(
      onTap: () => _openPhotoViewer(photo, index),
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(photo.id);
        } else {
          _toggleSelection(photo.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: Theme.of(context).primaryColor, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo thumbnail
              Image.file(
                File(photo.thumbnailPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
              
              // Selection overlay
              if (isSelected)
                Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              
              // Selection checkbox
              if (_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.white : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              
              // Gradient overlay for text
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // File size info
              Positioned(
                bottom: 4,
                left: 8,
                child: Text(
                  photo.fileSizeFormatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Date info
              Positioned(
                bottom: 4,
                right: 8,
                child: Text(
                  '${photo.uploadDate.day}/${photo.uploadDate.month}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
