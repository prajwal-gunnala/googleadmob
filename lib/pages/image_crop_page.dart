import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import '../models/photo_model.dart';
import '../services/photo_service.dart';

class ImageCropPage extends StatefulWidget {
  final PhotoModel photo;
  final VoidCallback onPhotoCropped;

  const ImageCropPage({
    super.key,
    required this.photo,
    required this.onPhotoCropped,
  });

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  final PhotoService _photoService = PhotoService();
  bool _isProcessing = false;
  img.Image? _originalImage;
  double _cropX = 0;
  double _cropY = 0;
  double _cropWidth = 1;
  double _cropHeight = 1;

  // For interactive crop
  double? _startDragX, _startDragY;
  double? _startCropX, _startCropY, _startCropWidth, _startCropHeight;
  bool _isDragging = false;
  bool _isResizing = false;
  String _resizeHandle = '';

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.photo.originalPath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        setState(() {
          _originalImage = image;
          _cropWidth = image.width.toDouble();
          _cropHeight = image.height.toDouble();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cropAndSave() async {
    if (_originalImage == null) return;

    try {
      setState(() {
        _isProcessing = true;
      });

      await _photoService.initialize();

      // Crop the image using the image package
      final croppedImage = img.copyCrop(
        _originalImage!,
        x: _cropX.round(),
        y: _cropY.round(),
        width: _cropWidth.round(),
        height: _cropHeight.round(),
      );

      // Save the cropped image using PhotoService
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cropped_photo_$timestamp.jpg';
      final tempPath = '${tempDir.path}/$fileName';
      final croppedBytes = img.encodeJpg(croppedImage, quality: 90);
      await File(tempPath).writeAsBytes(croppedBytes);

      // Save to PhotoService (this will move to app storage and update metadata)
      final savedPhoto = await _photoService.saveCroppedPhoto(File(tempPath));

      widget.onPhotoCropped();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image cropped and saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<String> _getPhotosDir() async {
    // This is a simple implementation - in a real app you'd use the PhotoService
    final appDocDir = Directory.systemTemp; // Simplified for demo
    return appDocDir.path;
  }

  Future<String> _createThumbnail(File originalFile, String fileName) async {
    // Simplified thumbnail creation
    return originalFile.path;
  }

  Future<void> _saveMetadata(PhotoModel photo) async {
    // Simplified metadata saving
    // In a real implementation, this would use the PhotoService
  }

  void _setCropToSquare() {
    if (_originalImage == null) return;
    final size = _originalImage!.width < _originalImage!.height 
        ? _originalImage!.width 
        : _originalImage!.height;
    setState(() {
      _cropX = (_originalImage!.width - size) / 2;
      _cropY = (_originalImage!.height - size) / 2;
      _cropWidth = size.toDouble();
      _cropHeight = size.toDouble();
    });
  }

  void _resetCrop() {
    if (_originalImage == null) return;
    setState(() {
      _cropX = 0;
      _cropY = 0;
      _cropWidth = _originalImage!.width.toDouble();
      _cropHeight = _originalImage!.height.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        centerTitle: true,
        actions: [
          if (!_isProcessing && _originalImage != null)
            TextButton(
              onPressed: _cropAndSave,
              child: const Text(
                'Save',
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
                  Text('Processing image...'),
                ],
              ),
            )
          : _originalImage == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final imageWidth = constraints.maxWidth - 32;
                    final imageHeight = constraints.maxHeight * 0.5;
                    final scaleX = imageWidth / _originalImage!.width;
                    final scaleY = imageHeight / _originalImage!.height;
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(widget.photo.originalPath),
                                      fit: BoxFit.contain,
                                      width: imageWidth,
                                      height: imageHeight,
                                    ),
                                  ),
                                ),
                                // Crop rectangle overlay
                                Positioned(
                                  left: 16 + _cropX * scaleX,
                                  top: 16 + _cropY * scaleY,
                                  child: GestureDetector(
                                    onPanStart: (details) {
                                      final local = details.localPosition;
                                      final handle = _getHandle(local.dx, local.dy, scaleX, scaleY);
                                      if (handle.isNotEmpty) {
                                        _isResizing = true;
                                        _resizeHandle = handle;
                                        _startDragX = local.dx;
                                        _startDragY = local.dy;
                                        _startCropX = _cropX;
                                        _startCropY = _cropY;
                                        _startCropWidth = _cropWidth;
                                        _startCropHeight = _cropHeight;
                                      } else {
                                        _isDragging = true;
                                        _startDragX = local.dx;
                                        _startDragY = local.dy;
                                        _startCropX = _cropX;
                                        _startCropY = _cropY;
                                      }
                                    },
                                    onPanUpdate: (details) {
                                      final dx = details.localPosition.dx - (_startDragX ?? 0);
                                      final dy = details.localPosition.dy - (_startDragY ?? 0);
                                      setState(() {
                                        if (_isResizing) {
                                          switch (_resizeHandle) {
                                            case 'tl':
                                              _cropX = (_startCropX! + dx / scaleX).clamp(0, _cropX + _cropWidth - 10);
                                              _cropY = (_startCropY! + dy / scaleY).clamp(0, _cropY + _cropHeight - 10);
                                              _cropWidth = (_startCropWidth! - dx / scaleX).clamp(10, _originalImage!.width - _cropX);
                                              _cropHeight = (_startCropHeight! - dy / scaleY).clamp(10, _originalImage!.height - _cropY);
                                              break;
                                            case 'tr':
                                              _cropY = (_startCropY! + dy / scaleY).clamp(0, _cropY + _cropHeight - 10);
                                              _cropWidth = (_startCropWidth! + dx / scaleX).clamp(10, _originalImage!.width - _cropX);
                                              _cropHeight = (_startCropHeight! - dy / scaleY).clamp(10, _originalImage!.height - _cropY);
                                              break;
                                            case 'bl':
                                              _cropX = (_startCropX! + dx / scaleX).clamp(0, _cropX + _cropWidth - 10);
                                              _cropWidth = (_startCropWidth! - dx / scaleX).clamp(10, _originalImage!.width - _cropX);
                                              _cropHeight = (_startCropHeight! + dy / scaleY).clamp(10, _originalImage!.height - _cropY);
                                              break;
                                            case 'br':
                                              _cropWidth = (_startCropWidth! + dx / scaleX).clamp(10, _originalImage!.width - _cropX);
                                              _cropHeight = (_startCropHeight! + dy / scaleY).clamp(10, _originalImage!.height - _cropY);
                                              break;
                                          }
                                        } else if (_isDragging) {
                                          _cropX = (_startCropX! + dx / scaleX).clamp(0, _originalImage!.width - _cropWidth);
                                          _cropY = (_startCropY! + dy / scaleY).clamp(0, _originalImage!.height - _cropHeight);
                                        }
                                      });
                                    },
                                    onPanEnd: (details) {
                                      _isDragging = false;
                                      _isResizing = false;
                                      _resizeHandle = '';
                                    },
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: _cropWidth * scaleX,
                                          height: _cropHeight * scaleY,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.blue, width: 2),
                                            color: Colors.blue.withOpacity(0.1),
                                          ),
                                        ),
                                        // Handles
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          child: _buildHandle(),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: _buildHandle(),
                                        ),
                                        Positioned(
                                          left: 0,
                                          bottom: 0,
                                          child: _buildHandle(),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: _buildHandle(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Drag/resize the rectangle to crop any area',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Crop Size: ${_cropWidth.round()} × ${_cropHeight.round()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isProcessing ? null : _cropAndSave,
                                  icon: const Icon(Icons.crop),
                                  label: const Text('Crop & Save'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blue, width: 2),
        shape: BoxShape.circle,
      ),
    );
  }

  String _getHandle(double dx, double dy, double scaleX, double scaleY) {
    // Detect which corner handle is being touched
    if (dx < 16 && dy < 16) return 'tl';
    if (dx > _cropWidth * scaleX - 16 && dy < 16) return 'tr';
    if (dx < 16 && dy > _cropHeight * scaleY - 16) return 'bl';
    if (dx > _cropWidth * scaleX - 16 && dy > _cropHeight * scaleY - 16) return 'br';
    return '';
  }
}
