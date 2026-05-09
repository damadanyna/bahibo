import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ChatMediaCacheService {
  ChatMediaCacheService._();

  static final ChatMediaCacheService instance = ChatMediaCacheService._();
  final Map<String, File> _resolvedFiles = <String, File>{};

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'banayChatMediaCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 240,
    ),
  );

  Future<File?> getCachedFile(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final inMemory = _resolvedFiles[normalizedUrl];
    if (inMemory != null) {
      return inMemory;
    }

    final cached = await _cacheManager.getFileFromCache(normalizedUrl);
    final file = cached?.file;
    if (file != null) {
      _resolvedFiles[normalizedUrl] = file;
    }
    return file;
  }

  File? peekResolvedFile(String url) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    return _resolvedFiles[normalizedUrl];
  }

  Future<File> getOrDownloadFile(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const FileSystemException('Chat media URL is empty');
    }

    final inMemory = _resolvedFiles[normalizedUrl];
    if (inMemory != null) {
      return inMemory;
    }

    final cached = await _cacheManager.getFileFromCache(normalizedUrl);
    if (cached != null) {
      _resolvedFiles[normalizedUrl] = cached.file;
      return cached.file;
    }

    final downloaded = await _cacheManager.getSingleFile(normalizedUrl);
    _resolvedFiles[normalizedUrl] = downloaded;
    return downloaded;
  }

  Future<void> prefetch(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return;
    }

    try {
      await getOrDownloadFile(normalizedUrl);
    } catch (_) {
      // Ignore cache warmup failures so media rendering stays non-blocking.
    }
  }
}
