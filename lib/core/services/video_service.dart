import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
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

  // Create thumbnail for video using video_player
  Future<String> _createThumbnail(File videoFile, String fileName) async {
    try {
      final thumbnailPath = '${_thumbnailsDir.path}/thumb_${fileName.replaceAll('.mp4', '.jpg')}';
      
      // For now, create a placeholder file
      // In a production app, you could use video_player or video_thumbnail package
      // to extract an actual frame from the video
      await File(thumbnailPath).create();
      
      return thumbnailPath;
    } catch (e) {
      print('Error creating video thumbnail: $e');
      return videoFile.path;
    }
  }

  // Get video duration using video_player package 
  Future<Duration> _getVideoDuration(File videoFile) async {
    try {
      // Use video_player to get actual video duration
      final videoPlayerController = VideoPlayerController.file(videoFile);
      await videoPlayerController.initialize();
      
      final duration = videoPlayerController.value.duration;
      await videoPlayerController.dispose();
      
      return duration;
    } catch (e) {
      print('Error getting video duration: $e');
      // Return a reasonable default based on file size
      final fileSize = await videoFile.length();
      // Rough estimate: 1MB per 10 seconds of video
      final estimatedSeconds = (fileSize / (1024 * 1024) * 10).clamp(10, 300).toInt();
      return Duration(seconds: estimatedSeconds);
    }
  }

  // Trim video (simplified - copies the video with trimmed metadata)
  // Note: This creates a copy of the original video but saves trimmed duration info
  // For actual video trimming, you'd need FFmpeg or similar video processing library
  Future<VideoModel?> trimVideo(VideoModel originalVideo, Duration startTime, Duration endTime) async {
    try {
      // Validate trim parameters
      if (startTime.isNegative) {
        print('Error: Start time cannot be negative');
        return null;
      }
      
      if (startTime >= endTime) {
        print('Error: Start time must be before end time');
        return null;
      }
      
      // Don't restrict based on original duration since we're just copying
      // In a real trim, you'd validate against actual video duration
      // But since we're just copying and setting metadata, allow any duration
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'trimmed_video_$timestamp.mp4';
      final outputPath = '${_videosDir.path}/$fileName';
      
      // Copy the original video file
      // Note: In a production app, you'd use FFmpeg to actually trim the video
      await File(originalVideo.originalPath).copy(outputPath);
      
      // Calculate trimmed duration
      final duration = endTime - startTime;
      
      print('Video copied for "trimming" from ${startTime.inSeconds}s to ${endTime.inSeconds}s (Duration: ${duration.inSeconds}s)');
      
      // Create thumbnail - reuse the original thumbnail for simplicity
      final thumbnailPath = originalVideo.thumbnailPath;
      
      // Get file size
      final fileSize = await File(outputPath).length();
      
      // Create video model with trimmed metadata
      final trimmedVideo = VideoModel(
        id: 'trimmed_$timestamp',
        fileName: fileName,
        originalPath: outputPath,
        thumbnailPath: thumbnailPath,
        uploadDate: DateTime.now(),
        fileSize: fileSize,
        duration: duration, // This reflects the intended trim duration (can be any length)
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
