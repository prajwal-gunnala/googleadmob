import 'dart:io';

class VideoModel {
  final String id;
  final String fileName;
  final String originalPath;
  final String thumbnailPath;
  final DateTime uploadDate;
  final int fileSize;
  final Duration duration;

  VideoModel({
    required this.id,
    required this.fileName,
    required this.originalPath,
    required this.thumbnailPath,
    required this.uploadDate,
    required this.fileSize,
    required this.duration,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '${fileSize} B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get fileExists => File(originalPath).existsSync();
  bool get thumbnailExists => File(thumbnailPath).existsSync();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'originalPath': originalPath,
      'thumbnailPath': thumbnailPath,
      'uploadDate': uploadDate.toIso8601String(),
      'fileSize': fileSize,
      'duration': duration.inMilliseconds,
    };
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'],
      fileName: json['fileName'],
      originalPath: json['originalPath'],
      thumbnailPath: json['thumbnailPath'],
      uploadDate: DateTime.parse(json['uploadDate']),
      fileSize: json['fileSize'],
      duration: Duration(milliseconds: json['duration']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
