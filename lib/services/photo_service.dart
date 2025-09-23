import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import '../models/photo_model.dart';

class PhotoService {
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  final ImagePicker _picker = ImagePicker();
  late Directory _photosDir;
  late Directory _thumbnailsDir;
  late File _metadataFile;

  // Initialize directories
  Future<void> initialize() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory('${appDocDir.path}/photos/original');
    _thumbnailsDir = Directory('${appDocDir.path}/photos/thumbnails');
    
    // Create directories if they don't exist
    if (!_photosDir.existsSync()) {
      _photosDir.createSync(recursive: true);
    }
    if (!_thumbnailsDir.existsSync()) {
      _thumbnailsDir.createSync(recursive: true);
    }
    
    _metadataFile = File('${appDocDir.path}/photos/metadata.json');
  }

  // Pick image from camera
  Future<PhotoModel?> pickFromCamera() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        return await _savePhoto(File(image.path));
      }
    } catch (e) {
      print('Error picking from camera: $e');
    }
    return null;
  }

  // Pick image from gallery
  Future<PhotoModel?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        return await _savePhoto(File(image.path));
      }
    } catch (e) {
      print('Error picking from gallery: $e');
    }
    return null;
  }

  // Save photo to app storage
  Future<PhotoModel> _savePhoto(File sourceFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'photo_$timestamp.jpg';
    
    // Copy original image
    final originalPath = '${_photosDir.path}/$fileName';
    final originalFile = await sourceFile.copy(originalPath);
    
    // Create thumbnail
    final thumbnailPath = await _createThumbnail(originalFile, fileName);
    
    // Get file size
    final fileSize = await originalFile.length();
    
    // Create photo model
    final photo = PhotoModel(
      id: 'photo_$timestamp',
      fileName: fileName,
      originalPath: originalPath,
      thumbnailPath: thumbnailPath,
      uploadDate: DateTime.now(),
      fileSize: fileSize,
    );
    
    // Save metadata
    await _saveMetadata(photo);
    
    return photo;
  }

  // Create thumbnail
  Future<String> _createThumbnail(File originalFile, String fileName) async {
    try {
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        // Resize to thumbnail (300x300 max, maintain aspect ratio)
        final thumbnail = img.copyResize(
          image,
          width: image.width > image.height ? 300 : null,
          height: image.height > image.width ? 300 : null,
        );
        
        final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);
        final thumbnailPath = '${_thumbnailsDir.path}/thumb_$fileName';
        
        await File(thumbnailPath).writeAsBytes(thumbnailBytes);
        return thumbnailPath;
      }
    } catch (e) {
      print('Error creating thumbnail: $e');
    }
    
    // Fallback: use original image as thumbnail
    return originalFile.path;
  }

  // Save metadata
  Future<void> _saveMetadata(PhotoModel photo) async {
    try {
      List<PhotoModel> photos = await getPhotos();
      photos.add(photo);
      
      final metadata = {
        'photos': photos.map((p) => p.toJson()).toList(),
      };
      
      await _metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      print('Error saving metadata: $e');
    }
  }

  // Get all photos
  Future<List<PhotoModel>> getPhotos() async {
    try {
      if (!_metadataFile.existsSync()) {
        return [];
      }
      
      final jsonString = await _metadataFile.readAsString();
      final data = jsonDecode(jsonString);
      
      final List<dynamic> photosJson = data['photos'] ?? [];
      return photosJson.map((json) => PhotoModel.fromJson(json)).toList();
    } catch (e) {
      print('Error getting photos: $e');
      return [];
    }
  }

  // Delete photo
  Future<bool> deletePhoto(PhotoModel photo) async {
    try {
      // Delete files
      final originalFile = File(photo.originalPath);
      final thumbnailFile = File(photo.thumbnailPath);
      
      if (originalFile.existsSync()) originalFile.deleteSync();
      if (thumbnailFile.existsSync()) thumbnailFile.deleteSync();
      
      // Update metadata
      final photos = await getPhotos();
      photos.removeWhere((p) => p.id == photo.id);
      
      final metadata = {
        'photos': photos.map((p) => p.toJson()).toList(),
      };
      
      await _metadataFile.writeAsString(jsonEncode(metadata));
      return true;
    } catch (e) {
      print('Error deleting photo: $e');
      return false;
    }
  }

  // Save photo to device gallery using Gal
  Future<bool> saveToGallery(PhotoModel photo) async {
    try {
      // Request permissions
      if (!await Gal.hasAccess()) {
        final hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          throw Exception('Gallery access denied');
        }
      }

      // Save to gallery
      await Gal.putImage(photo.originalPath);
      return true;
    } catch (e) {
      print('Error saving to gallery: $e');
      return false;
    }
  }

  // Get storage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final photos = await getPhotos();
      int totalSize = 0;
      
      for (final photo in photos) {
        totalSize += photo.fileSize;
      }
      
      return {
        'photoCount': photos.length,
        'totalSize': totalSize,
        'totalSizeFormatted': _formatFileSize(totalSize),
      };
    } catch (e) {
      return {
        'photoCount': 0,
        'totalSize': 0,
        'totalSizeFormatted': '0B',
      };
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // Delete multiple photos
  Future<bool> deleteMultiplePhotos(List<PhotoModel> photosToDelete) async {
    try {
      // Delete files
      for (final photo in photosToDelete) {
        final originalFile = File(photo.originalPath);
        final thumbnailFile = File(photo.thumbnailPath);
        
        if (originalFile.existsSync()) originalFile.deleteSync();
        if (thumbnailFile.existsSync()) thumbnailFile.deleteSync();
      }
      
      // Update metadata
      final photos = await getPhotos();
      final idsToDelete = photosToDelete.map((p) => p.id).toSet();
      photos.removeWhere((p) => idsToDelete.contains(p.id));
      
      final metadata = {
        'photos': photos.map((p) => p.toJson()).toList(),
      };
      
      await _metadataFile.writeAsString(jsonEncode(metadata));
      return true;
    } catch (e) {
      print('Error deleting multiple photos: $e');
      return false;
    }
  }

  // Crop photo and save as new photo
  Future<PhotoModel?> cropPhoto(PhotoModel originalPhoto, int x, int y, int width, int height) async {
    try {
      final originalFile = File(originalPhoto.originalPath);
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        // Crop the image
        final croppedImage = img.copyCrop(image, 
          x: x, 
          y: y, 
          width: width, 
          height: height
        );
        
        // Save cropped image
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'cropped_photo_$timestamp.jpg';
        final croppedPath = '${_photosDir.path}/$fileName';
        
        final croppedBytes = img.encodeJpg(croppedImage, quality: 90);
        await File(croppedPath).writeAsBytes(croppedBytes);
        
        // Create thumbnail for cropped image
        final thumbnailPath = await _createThumbnail(File(croppedPath), fileName);
        
        // Get file size
        final fileSize = await File(croppedPath).length();
        
        // Create photo model
        final croppedPhoto = PhotoModel(
          id: 'cropped_$timestamp',
          fileName: fileName,
          originalPath: croppedPath,
          thumbnailPath: thumbnailPath,
          uploadDate: DateTime.now(),
          fileSize: fileSize,
        );
        
        // Save metadata
        await _saveMetadata(croppedPhoto);
        
        return croppedPhoto;
      }
    } catch (e) {
      print('Error cropping photo: $e');
    }
    return null;
  }

  // Create side-by-side collage from two photos
  Future<PhotoModel?> createCollage(PhotoModel photo1, PhotoModel photo2) async {
    try {
      final file1 = File(photo1.originalPath);
      final file2 = File(photo2.originalPath);
      
      final bytes1 = await file1.readAsBytes();
      final bytes2 = await file2.readAsBytes();
      
      final image1 = img.decodeImage(bytes1);
      final image2 = img.decodeImage(bytes2);
      
      if (image1 != null && image2 != null) {
        // Calculate dimensions for side-by-side layout
        final maxHeight = image1.height > image2.height ? image1.height : image2.height;
        
        // Resize images to same height while maintaining aspect ratio
        final resized1 = img.copyResize(image1, height: maxHeight);
        final resized2 = img.copyResize(image2, height: maxHeight);
        
        // Create collage canvas
        final collageWidth = resized1.width + resized2.width;
        final collage = img.Image(width: collageWidth, height: maxHeight);
        
        // Fill with white background
        img.fill(collage, color: img.ColorRgb8(255, 255, 255));
        
        // Composite images side by side
        img.compositeImage(collage, resized1, dstX: 0, dstY: 0);
        img.compositeImage(collage, resized2, dstX: resized1.width, dstY: 0);
        
        // Save collage
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'collage_$timestamp.jpg';
        final collagePath = '${_photosDir.path}/$fileName';
        
        final collageBytes = img.encodeJpg(collage, quality: 90);
        await File(collagePath).writeAsBytes(collageBytes);
        
        // Create thumbnail
        final thumbnailPath = await _createThumbnail(File(collagePath), fileName);
        
        // Get file size
        final fileSize = await File(collagePath).length();
        
        // Create photo model
        final collagePhoto = PhotoModel(
          id: 'collage_$timestamp',
          fileName: fileName,
          originalPath: collagePath,
          thumbnailPath: thumbnailPath,
          uploadDate: DateTime.now(),
          fileSize: fileSize,
        );
        
        // Save metadata
        await _saveMetadata(collagePhoto);
        
        return collagePhoto;
      }
    } catch (e) {
      print('Error creating collage: $e');
    }
    return null;
  }
}
