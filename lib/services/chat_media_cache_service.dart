import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ChatMediaCacheService {
  ChatMediaCacheService._();

  static final ChatMediaCacheService instance = ChatMediaCacheService._();

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

    final cached = await _cacheManager.getFileFromCache(normalizedUrl);
    return cached?.file;
  }

  Future<File> getOrDownloadFile(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const FileSystemException('Chat media URL is empty');
    }

    final cached = await _cacheManager.getFileFromCache(normalizedUrl);
    if (cached != null) {
      return cached.file;
    }

    return _cacheManager.getSingleFile(normalizedUrl);
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
