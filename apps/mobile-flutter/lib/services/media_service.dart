import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';

/// Configuration for media limits
class MediaConfig {
  // Max file sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 25 * 1024 * 1024; // 25MB
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxVoiceSize = 5 * 1024 * 1024; // 5MB
  static const int maxVoiceDuration = 120; // 2 minutes in seconds
  static const int maxVideoDuration = 15; // 15 seconds for video recording

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
  final int? audioDuration; // Duration in seconds for voice messages

  MediaUploadResult({
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.mediaType,
    this.audioDuration,
  });
}

enum MediaType { image, video, file, voice }

/// Service for handling media picking, compression, and upload
class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  RecorderController? _recorderController;
  
  // Voice recording state
  DateTime? _recordingStartTime;
  String? _currentRecordingPath;
  
  /// Get the recorder controller for waveform display
  RecorderController? get recorderController => _recorderController;
  
  /// Check if currently recording
  bool isRecording() {
    return _recorderController?.isRecording ?? false;
  }
  
  /// Request microphone permission with proper handling for denied/permanently denied
  Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      // Request the permission
      status = await Permission.microphone.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      // Permission was permanently denied, user needs to go to settings
      throw Exception('Microphone permission is permanently denied. Please enable it in app settings.');
    }
    
    return false;
  }

  /// Request camera permission with proper handling
  Future<bool> requestCameraPermission() async {
    var status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      throw Exception('Camera permission is permanently denied. Please enable it in app settings.');
    }
    
    return false;
  }

  /// Request all media permissions (camera + microphone) at once
  Future<Map<Permission, PermissionStatus>> requestMediaPermissions() async {
    return await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  /// Check if we have both camera and microphone permissions
  Future<bool> hasMediaPermissions() async {
    final camera = await Permission.camera.isGranted;
    final microphone = await Permission.microphone.isGranted;
    return camera && microphone;
  }

  /// Open app settings (useful when permission is permanently denied)
  Future<bool> openPermissionSettings() async {
    return await openAppSettings();
  }
  
  /// Start voice recording
  Future<bool> startRecording() async {
    try {
      // Check permission
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission is required to record voice messages. Please allow microphone access.');
      }
      
      // Create recorder controller
      _recorderController = RecorderController()
        ..androidEncoder = AndroidEncoder.aac
        ..androidOutputFormat = AndroidOutputFormat.mpeg4
        ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 44100
        ..bitRate = 128000;
      
      // Create temp file path
      final tempDir = await getTemporaryDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '${tempDir.path}/$fileName';
      
      // Start recording
      await _recorderController!.record(path: _currentRecordingPath);
      
      _recordingStartTime = DateTime.now();
      return true;
    } catch (e) {
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _recorderController?.dispose();
      _recorderController = null;
      throw Exception('Failed to start recording: $e');
    }
  }
  
  /// Stop voice recording and return the file with duration
  Future<({File file, int durationSeconds})?> stopRecording() async {
    try {
      if (_recorderController == null || !_recorderController!.isRecording) {
        return null;
      }
      
      final path = await _recorderController!.stop();
      if (path == null || _currentRecordingPath == null) {
        return null;
      }
      
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) {
        return null;
      }
      
      // Calculate duration
      final durationSeconds = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;
      
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _recorderController?.dispose();
      _recorderController = null;
      
      return (file: file, durationSeconds: durationSeconds);
    } catch (e) {
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _recorderController?.dispose();
      _recorderController = null;
      return null;
    }
  }
  
  /// Cancel voice recording
  Future<void> cancelRecording() async {
    try {
      if (_recorderController != null && _recorderController!.isRecording) {
        await _recorderController!.stop();
      }
      
      // Delete the temp file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } finally {
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _recorderController?.dispose();
      _recorderController = null;
    }
  }
  
  /// Get current recording duration in seconds
  int getRecordingDuration() {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }
  
  /// Upload a voice message
  Future<MediaUploadResult> uploadVoiceMessage({
    required File file,
    required int durationSeconds,
    required String chatRoomId,
    required String senderId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final fileSize = await file.length();
      
      // Check size limit
      if (fileSize > MediaConfig.maxVoiceSize) {
        throw Exception(
          'Voice message is too large. Maximum size is ${MediaConfig.maxVoiceSize ~/ (1024 * 1024)}MB',
        );
      }
      
      final uniqueFileName = '${_uuid.v4()}_voice.m4a';
      final storagePath = 'chats/$chatRoomId/voice/$senderId/$uniqueFileName';
      
      // Upload file
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/mp4'),
      );
      
      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      
      await uploadTask;
      final mediaUrl = await ref.getDownloadURL();
      
      return MediaUploadResult(
        mediaUrl: mediaUrl,
        fileName: uniqueFileName,
        fileSize: fileSize,
        mimeType: 'audio/mp4',
        mediaType: MediaType.voice,
        audioDuration: durationSeconds,
      );
    } catch (e) {
      throw Exception('Failed to upload voice message: $e');
    }
  }
  
  /// Format duration for display (e.g., "0:45" or "1:23")
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  /// Dispose resources
  void dispose() {
    _recorderController?.dispose();
  }

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

  /// Pick a video from gallery or camera with duration limit and auto-compression
  Future<File?> pickVideo({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: MediaConfig.maxVideoDuration), // 15 seconds limit
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final fileSize = await file.length();

      // If file is under limit, return as-is
      if (fileSize <= MediaConfig.maxVideoSize) {
        return file;
      }

      // Try to compress the video
      final compressedFile = await compressVideo(file);
      if (compressedFile == null) {
        throw Exception(
          'Video is too large (${formatFileSize(fileSize)}). Maximum size is 25MB. Try recording a shorter video.',
        );
      }

      final compressedSize = await compressedFile.length();
      if (compressedSize > MediaConfig.maxVideoSize) {
        throw Exception(
          'Video is still too large after compression (${formatFileSize(compressedSize)}). Please record a shorter video.',
        );
      }

      return compressedFile;
    } catch (e) {
      if (e.toString().contains('Video is')) {
        rethrow; // Don't wrap our own exceptions
      }
      throw Exception('Failed to pick video: $e');
    }
  }

  /// Compress a video file to reduce size
  /// Tries progressively lower quality until file is under 25MB
  Future<File?> compressVideo(File file, {VideoQuality quality = VideoQuality.MediumQuality}) async {
    try {
      final MediaInfo? info = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        deleteOrigin: false, // Keep original
        includeAudio: true,
      );
      
      if (info == null || info.file == null) {
        return null;
      }
      
      final compressedFile = info.file!;
      final compressedSize = await compressedFile.length();
      
      // If still too large and we can reduce quality more, try again
      if (compressedSize > MediaConfig.maxVideoSize) {
        if (quality == VideoQuality.MediumQuality) {
          return compressVideo(file, quality: VideoQuality.LowQuality);
        } else if (quality == VideoQuality.LowQuality) {
          return compressVideo(file, quality: VideoQuality.Res640x480Quality);
        }
        // Can't compress further
        return null;
      }
      
      return compressedFile;
    } catch (e) {
      return null;
    }
  }

  /// Cancel any ongoing video compression
  Future<void> cancelVideoCompression() async {
    await VideoCompress.cancelCompression();
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

