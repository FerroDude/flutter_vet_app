import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Centralized media cache service for managing cached files
/// 
/// Cache structure:
/// /app_cache/
///   /videos/      - Cached video files
///   /thumbnails/  - Video thumbnails
///   /voice/       - Voice message recordings
///   /images/      - Cached images
class MediaCacheService {
  static MediaCacheService? _instance;
  static MediaCacheService get instance => _instance ??= MediaCacheService._();
  
  MediaCacheService._();
  
  String? _cacheBasePath;
  
  /// Cache subdirectory names
  static const String videosDir = 'videos';
  static const String thumbnailsDir = 'thumbnails';
  static const String voiceDir = 'voice';
  static const String imagesDir = 'images';
  
  /// Initialize the cache service and create directories
  Future<void> init() async {
    final cacheDir = await getTemporaryDirectory();
    _cacheBasePath = '${cacheDir.path}/app_cache';
    
    // Create all cache subdirectories
    await _ensureDirectoryExists(videosDir);
    await _ensureDirectoryExists(thumbnailsDir);
    await _ensureDirectoryExists(voiceDir);
    await _ensureDirectoryExists(imagesDir);
  }
  
  /// Get base cache path
  String get basePath {
    if (_cacheBasePath == null) {
      throw Exception('MediaCacheService not initialized. Call init() first.');
    }
    return _cacheBasePath!;
  }
  
  /// Get path for a specific cache subdirectory
  String getDirectoryPath(String subdir) => '$basePath/$subdir';
  
  /// Ensure a directory exists
  Future<Directory> _ensureDirectoryExists(String subdir) async {
    final dir = Directory(getDirectoryPath(subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
  
  /// Generate a consistent cache filename from a URL
  String generateCacheFileName(String url, {String? extension}) {
    final hash = url.hashCode.abs().toString();
    final ext = extension ?? _getExtensionFromUrl(url) ?? 'dat';
    return '${hash}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.$ext';
  }
  
  /// Generate a consistent cache filename from URL (without timestamp for lookups)
  String generateStableCacheFileName(String url, {String? extension}) {
    final hash = url.hashCode.abs().toString();
    final ext = extension ?? _getExtensionFromUrl(url) ?? 'dat';
    return '$hash.$ext';
  }
  
  String? _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        return path.substring(lastDot + 1).split('?').first;
      }
    } catch (_) {}
    return null;
  }
  
  // ============ VIDEO CACHING ============
  
  /// Get the cached video file path for a URL
  String getVideoCachePath(String videoUrl, {String? fileName}) {
    final ext = fileName?.split('.').last ?? 'mp4';
    final cacheFileName = 'video_${videoUrl.hashCode.abs()}.$ext';
    return '${getDirectoryPath(videosDir)}/$cacheFileName';
  }
  
  /// Check if a video is cached
  Future<bool> isVideoCached(String videoUrl, {String? fileName}) async {
    final path = getVideoCachePath(videoUrl, fileName: fileName);
    return await File(path).exists();
  }
  
  /// Get cached video file (null if not cached)
  Future<File?> getCachedVideo(String videoUrl, {String? fileName}) async {
    final path = getVideoCachePath(videoUrl, fileName: fileName);
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
  
  /// Save video to cache
  Future<File> cacheVideo(String videoUrl, List<int> bytes, {String? fileName}) async {
    final path = getVideoCachePath(videoUrl, fileName: fileName);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }
  
  // ============ THUMBNAIL CACHING ============
  
  /// Get the thumbnail cache path for a video URL
  String getThumbnailCachePath(String videoUrl) {
    final cacheFileName = 'thumb_${videoUrl.hashCode.abs()}.jpg';
    return '${getDirectoryPath(thumbnailsDir)}/$cacheFileName';
  }
  
  /// Check if a thumbnail is cached
  Future<bool> isThumbnailCached(String videoUrl) async {
    final path = getThumbnailCachePath(videoUrl);
    return await File(path).exists();
  }
  
  /// Get cached thumbnail file (null if not cached)
  Future<File?> getCachedThumbnail(String videoUrl) async {
    final path = getThumbnailCachePath(videoUrl);
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
  
  /// Generate and cache thumbnail from a video file
  Future<File?> generateAndCacheThumbnail(String videoUrl, String videoFilePath) async {
    try {
      // Generate thumbnail using video_compress
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoFilePath,
        quality: 75,
        position: -1, // Default position (usually 0 or middle)
      );
      
      if (thumbnailFile.existsSync()) {
        // Copy to our cache location
        final cachePath = getThumbnailCachePath(videoUrl);
        final cachedThumbnail = await thumbnailFile.copy(cachePath);
        return cachedThumbnail;
      }
    } catch (e) {
      // Thumbnail generation failed, return null
    }
    return null;
  }
  
  // ============ VOICE CACHING ============
  
  /// Get the voice message cache path
  String getVoiceCachePath(String messageId) {
    return '${getDirectoryPath(voiceDir)}/voice_$messageId.m4a';
  }
  
  /// Check if a voice message is cached
  Future<bool> isVoiceCached(String messageId) async {
    final path = getVoiceCachePath(messageId);
    return await File(path).exists();
  }
  
  /// Get cached voice file (null if not cached)
  Future<File?> getCachedVoice(String messageId) async {
    final path = getVoiceCachePath(messageId);
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
  
  /// Save voice to cache
  Future<File> cacheVoice(String messageId, List<int> bytes) async {
    final path = getVoiceCachePath(messageId);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }
  
  // ============ IMAGE CACHING ============
  
  /// Get the image cache path for a URL
  String getImageCachePath(String imageUrl) {
    final ext = _getExtensionFromUrl(imageUrl) ?? 'jpg';
    final cacheFileName = 'img_${imageUrl.hashCode.abs()}.$ext';
    return '${getDirectoryPath(imagesDir)}/$cacheFileName';
  }
  
  /// Check if an image is cached
  Future<bool> isImageCached(String imageUrl) async {
    final path = getImageCachePath(imageUrl);
    return await File(path).exists();
  }
  
  // ============ CACHE MANAGEMENT ============
  
  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    int totalSize = 0;
    final baseDir = Directory(basePath);
    
    if (await baseDir.exists()) {
      await for (final entity in baseDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }
  
  /// Get cache size for a specific subdirectory in bytes
  Future<int> getCacheSizeForType(String subdir) async {
    int totalSize = 0;
    final dir = Directory(getDirectoryPath(subdir));
    
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }
  
  /// Get file count for a specific subdirectory
  Future<int> getFileCountForType(String subdir) async {
    int count = 0;
    final dir = Directory(getDirectoryPath(subdir));
    
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          count++;
        }
      }
    }
    
    return count;
  }
  
  /// Get detailed cache info for all types
  Future<Map<String, CacheTypeInfo>> getDetailedCacheInfo() async {
    final types = [videosDir, thumbnailsDir, voiceDir, imagesDir];
    final result = <String, CacheTypeInfo>{};
    
    for (final type in types) {
      final size = await getCacheSizeForType(type);
      final count = await getFileCountForType(type);
      result[type] = CacheTypeInfo(
        size: size,
        fileCount: count,
        formattedSize: _formatBytes(size),
      );
    }
    
    return result;
  }
  
  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Get cache size formatted as string
  Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSize();
    return _formatBytes(bytes);
  }
  
  /// Clear all cached files
  Future<void> clearAllCache() async {
    final baseDir = Directory(basePath);
    if (await baseDir.exists()) {
      await baseDir.delete(recursive: true);
    }
    // Recreate directories
    await init();
  }
  
  /// Clear specific cache type
  Future<void> clearCacheType(String subdir) async {
    final dir = Directory(getDirectoryPath(subdir));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await _ensureDirectoryExists(subdir);
    }
  }
  
  /// Clear videos cache
  Future<void> clearVideosCache() => clearCacheType(videosDir);
  
  /// Clear thumbnails cache
  Future<void> clearThumbnailsCache() => clearCacheType(thumbnailsDir);
  
  /// Clear voice cache
  Future<void> clearVoiceCache() => clearCacheType(voiceDir);
  
  /// Clear images cache
  Future<void> clearImagesCache() => clearCacheType(imagesDir);
}

/// Information about a specific cache type
class CacheTypeInfo {
  final int size;
  final int fileCount;
  final String formattedSize;
  
  const CacheTypeInfo({
    required this.size,
    required this.fileCount,
    required this.formattedSize,
  });
}

