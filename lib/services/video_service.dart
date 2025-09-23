import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_model.dart';

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  final ImagePicker _picker = ImagePicker();
  late Directory _videosDir;
  late Directory _thumbnailsDir;
  late File _metadataFile;

  // Initialize directories
  Future<void> initialize() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _videosDir = Directory('${appDocDir.path}/videos/original');
    _thumbnailsDir = Directory('${appDocDir.path}/videos/thumbnails');
    
    // Create directories if they don't exist
    if (!_videosDir.existsSync()) {
      _videosDir.createSync(recursive: true);
    }
    if (!_thumbnailsDir.existsSync()) {
      _thumbnailsDir.createSync(recursive: true);
    }
    
    _metadataFile = File('${appDocDir.path}/videos/metadata.json');
  }

  // Pick video from gallery
  Future<VideoModel?> pickFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // Limit to 10 minutes
      );

      if (video != null) {
        return await _saveVideo(File(video.path));
      }
    } catch (e) {
      print('Error picking video from gallery: $e');
    }
    return null;
  }

  // Pick video from camera
  Future<VideoModel?> pickFromCamera() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission denied');
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5), // Limit camera recording to 5 minutes
      );

      if (video != null) {
        return await _saveVideo(File(video.path));
      }
    } catch (e) {
      print('Error picking video from camera: $e');
    }
    return null;
  }

  // Save video to app storage
  Future<VideoModel> _saveVideo(File sourceFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'video_$timestamp.mp4';
    
    // Copy original video
    final originalPath = '${_videosDir.path}/$fileName';
    final originalFile = await sourceFile.copy(originalPath);
    
    // Create thumbnail
    final thumbnailPath = await _createThumbnail(originalFile, fileName);
    
    // Get file size and duration
    final fileSize = await originalFile.length();
    final duration = await _getVideoDuration(originalFile);
    
    // Create video model
    final video = VideoModel(
      id: 'video_$timestamp',
      fileName: fileName,
      originalPath: originalPath,
      thumbnailPath: thumbnailPath,
      uploadDate: DateTime.now(),
      fileSize: fileSize,
      duration: duration,
    );
    
    // Save metadata
    await _saveMetadata(video);
    
    return video;
  }

  // Create thumbnail for video (simplified)
  Future<String> _createThumbnail(File videoFile, String fileName) async {
    try {
      // For now, create a placeholder thumbnail path
      // In a real implementation, you'd extract a frame from the video
      final thumbnailPath = '${_thumbnailsDir.path}/thumb_${fileName.replaceAll('.mp4', '.jpg')}';
      
      // Create a simple placeholder file for now
      // This should be replaced with actual video thumbnail generation
      await File(thumbnailPath).create();
      
      return thumbnailPath;
    } catch (e) {
      print('Error creating video thumbnail: $e');
      return videoFile.path;
    }
  }

  // Get video duration
  Future<Duration> _getVideoDuration(File videoFile) async {
    try {
      // This is a simple implementation. In a real app, you might want to use
      // a more robust method to get video duration
      return const Duration(seconds: 30); // Default duration
    } catch (e) {
      print('Error getting video duration: $e');
      return const Duration(seconds: 0);
    }
  }

  // Trim video (simplified - for now just copies the video)
  Future<VideoModel?> trimVideo(VideoModel originalVideo, Duration startTime, Duration endTime) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'trimmed_video_$timestamp.mp4';
      final outputPath = '${_videosDir.path}/$fileName';
      
      // For now, just copy the original video
      // In a real implementation, you'd use FFmpeg or similar to trim
      await File(originalVideo.originalPath).copy(outputPath);
      
      // Create thumbnail
      final thumbnailPath = await _createThumbnail(File(outputPath), fileName);
      
      // Get file size
      final fileSize = await File(outputPath).length();
      
      // Calculate trimmed duration
      final duration = endTime - startTime;
      
      // Create video model
      final trimmedVideo = VideoModel(
        id: 'trimmed_$timestamp',
        fileName: fileName,
        originalPath: outputPath,
        thumbnailPath: thumbnailPath,
        uploadDate: DateTime.now(),
        fileSize: fileSize,
        duration: duration,
      );
      
      // Save metadata
      await _saveMetadata(trimmedVideo);
      
      return trimmedVideo;
    } catch (e) {
      print('Error trimming video: $e');
      return null;
    }
  }

  // Save metadata
  Future<void> _saveMetadata(VideoModel video) async {
    try {
      List<VideoModel> videos = await getVideos();
      videos.add(video);
      
      final metadata = {
        'videos': videos.map((v) => v.toJson()).toList(),
      };
      
      await _metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      print('Error saving video metadata: $e');
    }
  }

  // Get all videos
  Future<List<VideoModel>> getVideos() async {
    try {
      if (!_metadataFile.existsSync()) {
        return [];
      }
      
      final jsonString = await _metadataFile.readAsString();
      final data = jsonDecode(jsonString);
      
      final List<dynamic> videosJson = data['videos'] ?? [];
      return videosJson.map((json) => VideoModel.fromJson(json)).toList();
    } catch (e) {
      print('Error getting videos: $e');
      return [];
    }
  }

  // Delete video
  Future<bool> deleteVideo(VideoModel video) async {
    try {
      // Delete files
      final originalFile = File(video.originalPath);
      final thumbnailFile = File(video.thumbnailPath);
      
      if (originalFile.existsSync()) originalFile.deleteSync();
      if (thumbnailFile.existsSync()) thumbnailFile.deleteSync();
      
      // Update metadata
      final videos = await getVideos();
      videos.removeWhere((v) => v.id == video.id);
      
      final metadata = {
        'videos': videos.map((v) => v.toJson()).toList(),
      };
      
      await _metadataFile.writeAsString(jsonEncode(metadata));
      return true;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  // Save video to device gallery
  Future<bool> saveToGallery(VideoModel video) async {
    try {
      // Request permissions
      if (!await Gal.hasAccess()) {
        final hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          throw Exception('Gallery access denied');
        }
      }

      // Save to gallery
      await Gal.putVideo(video.originalPath);
      return true;
    } catch (e) {
      print('Error saving video to gallery: $e');
      return false;
    }
  }

  // Get storage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final videos = await getVideos();
      int totalSize = 0;
      
      for (final video in videos) {
        totalSize += video.fileSize;
      }
      
      return {
        'videoCount': videos.length,
        'totalSize': totalSize,
        'totalSizeFormatted': _formatFileSize(totalSize),
      };
    } catch (e) {
      return {
        'videoCount': 0,
        'totalSize': 0,
        'totalSizeFormatted': '0B',
      };
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
