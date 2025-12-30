import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

/// Configuration for media limits
class MediaConfig {
  // Max file sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 25 * 1024 * 1024; // 25MB
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  // Image compression settings
  static const int imageQuality = 70; // 0-100
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int thumbnailWidth = 300;
  static const int thumbnailHeight = 300;

  // Allowed file extensions
  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  static const List<String> allowedVideoExtensions = ['mp4', 'mov', 'avi'];
  static const List<String> allowedFileExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
  ];
}

/// Result of a media upload operation
class MediaUploadResult {
  final String mediaUrl;
  final String? thumbnailUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final MediaType mediaType;

  MediaUploadResult({
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.mediaType,
  });
}

enum MediaType { image, video, file }

/// Service for handling media picking, compression, and upload
class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: MediaConfig.maxImageWidth.toDouble(),
        maxHeight: MediaConfig.maxImageHeight.toDouble(),
        imageQuality: MediaConfig.imageQuality,
      );

      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Pick a video from gallery or camera
  Future<File?> pickVideo({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3), // Limit video length
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileSize = await file.length();

      // Check file size
      if (fileSize > MediaConfig.maxVideoSize) {
        throw Exception(
          'Video is too large. Maximum size is ${MediaConfig.maxVideoSize ~/ (1024 * 1024)}MB',
        );
      }

      return file;
    } catch (e) {
      throw Exception('Failed to pick video: $e');
    }
  }

  /// Pick files using file picker
  Future<List<File>> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          ...MediaConfig.allowedImageExtensions,
          ...MediaConfig.allowedVideoExtensions,
          ...MediaConfig.allowedFileExtensions,
        ],
      );

      if (result == null || result.files.isEmpty) return [];

      final files = <File>[];
      for (final platformFile in result.files) {
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          final fileSize = await file.length();

          // Check file size based on type
          final mimeType = lookupMimeType(platformFile.path!) ?? '';
          final maxSize = _getMaxSizeForMimeType(mimeType);

          if (fileSize > maxSize) {
            throw Exception(
              'File "${platformFile.name}" is too large. Maximum size is ${maxSize ~/ (1024 * 1024)}MB',
            );
          }

          files.add(file);
        }
      }

      return files;
    } catch (e) {
      throw Exception('Failed to pick files: $e');
    }
  }

  /// Compress an image file
  Future<File> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: MediaConfig.imageQuality,
        minWidth: MediaConfig.maxImageWidth,
        minHeight: MediaConfig.maxImageHeight,
      );

      if (result == null) {
        return file; // Return original if compression fails
      }

      return File(result.path);
    } catch (e) {
      // Return original file if compression fails
      return file;
    }
  }

  /// Generate a thumbnail for an image
  Future<File?> generateImageThumbnail(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 60,
        minWidth: MediaConfig.thumbnailWidth,
        minHeight: MediaConfig.thumbnailHeight,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      return null;
    }
  }

  /// Upload a media file to Firebase Storage
  Future<MediaUploadResult> uploadMedia({
    required File file,
    required String chatRoomId,
    required String senderId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final mediaType = _getMediaType(mimeType);

      // Compress image if needed
      File fileToUpload = file;
      if (mediaType == MediaType.image) {
        final originalSize = await file.length();
        if (originalSize > MediaConfig.maxImageSize) {
          fileToUpload = await compressImage(file);
        }
      }

      final fileSize = await fileToUpload.length();
      final uniqueFileName = '${_uuid.v4()}_$fileName';
      final storagePath =
          'chats/$chatRoomId/media/$senderId/$uniqueFileName';

      // Upload main file
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        fileToUpload,
        SettableMetadata(contentType: mimeType),
      );

      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;
      final mediaUrl = await ref.getDownloadURL();

      // Generate and upload thumbnail for images
      String? thumbnailUrl;
      if (mediaType == MediaType.image) {
        final thumbnail = await generateImageThumbnail(fileToUpload);
        if (thumbnail != null) {
          final thumbnailPath =
              'chats/$chatRoomId/thumbnails/$senderId/thumb_$uniqueFileName';
          final thumbnailRef = _storage.ref().child(thumbnailPath);
          await thumbnailRef.putFile(
            thumbnail,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          thumbnailUrl = await thumbnailRef.getDownloadURL();
        }
      }

      return MediaUploadResult(
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        mediaType: mediaType,
      );
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  /// Upload multiple files
  Future<List<MediaUploadResult>> uploadMultipleMedia({
    required List<File> files,
    required String chatRoomId,
    required String senderId,
    void Function(int current, int total, double progress)? onProgress,
  }) async {
    final results = <MediaUploadResult>[];

    for (int i = 0; i < files.length; i++) {
      final result = await uploadMedia(
        file: files[i],
        chatRoomId: chatRoomId,
        senderId: senderId,
        onProgress: (progress) {
          onProgress?.call(i + 1, files.length, progress);
        },
      );
      results.add(result);
    }

    return results;
  }

  /// Delete a media file from Firebase Storage
  Future<void> deleteMedia(String mediaUrl) async {
    try {
      final ref = _storage.refFromURL(mediaUrl);
      await ref.delete();
    } catch (e) {
      // Silently fail - file might already be deleted
    }
  }

  /// Get media type from MIME type
  MediaType _getMediaType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return MediaType.image;
    } else if (mimeType.startsWith('video/')) {
      return MediaType.video;
    } else {
      return MediaType.file;
    }
  }

  /// Get max allowed file size for a MIME type
  int _getMaxSizeForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return MediaConfig.maxImageSize;
    } else if (mimeType.startsWith('video/')) {
      return MediaConfig.maxVideoSize;
    } else {
      return MediaConfig.maxFileSize;
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get file icon based on MIME type
  static String getFileIcon(String? mimeType) {
    if (mimeType == null) return '📄';

    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType.startsWith('video/')) return '🎬';
    if (mimeType.contains('pdf')) return '📕';
    if (mimeType.contains('word') || mimeType.contains('doc')) return '📘';
    if (mimeType.contains('excel') || mimeType.contains('sheet')) return '📗';
    if (mimeType.contains('text')) return '📝';

    return '📄';
  }
}

