class PhotoModel {
  final String id;
  final String fileName;
  final String originalPath;
  final String thumbnailPath;
  final DateTime uploadDate;
  final int fileSize;

  PhotoModel({
    required this.id,
    required this.fileName,
    required this.originalPath,
    required this.thumbnailPath,
    required this.uploadDate,
    required this.fileSize,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'originalPath': originalPath,
      'thumbnailPath': thumbnailPath,
      'uploadDate': uploadDate.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  // Create from JSON
  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'],
      fileName: json['fileName'],
      originalPath: json['originalPath'],
      thumbnailPath: json['thumbnailPath'],
      uploadDate: DateTime.parse(json['uploadDate']),
      fileSize: json['fileSize'],
    );
  }

  // Get file size in readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
