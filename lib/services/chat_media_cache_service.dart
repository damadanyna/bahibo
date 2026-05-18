import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

class ChatMediaCacheService {
  ChatMediaCacheService._();

  static final ChatMediaCacheService instance = ChatMediaCacheService._();

  final Map<String, File> _resolvedFiles = <String, File>{};
  final Map<String, Uint8List> _tinyThumbMemCache = <String, Uint8List>{};

  static const String _thumbDbFileName = 'banay_tiny_thumbs.db';
  static const String _thumbStoreName = 'tiny_thumbs';
  static final StoreRef<String, String> _thumbStore =
      StoreRef<String, String>(_thumbStoreName);

  Future<Database>? _thumbDbFuture;

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'banayChatMediaCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 240,
    ),
  );

  // ── Tiny-thumb helpers ──────────────────────────────────────────────────────

  Uint8List? peekTinyThumb(String url) {
    return _tinyThumbMemCache[url.trim()];
  }

  Future<Uint8List?> getTinyThumb(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) return null;

    final mem = _tinyThumbMemCache[normalizedUrl];
    if (mem != null) return mem;

    try {
      final db = await _openThumbDb();
      final encoded = await _thumbStore.record(normalizedUrl).get(db);
      if (encoded != null) {
        final bytes = base64Decode(encoded);
        _tinyThumbMemCache[normalizedUrl] = bytes;
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveTinyThumb(String url, Uint8List bytes) async {
    _tinyThumbMemCache[url] = bytes;
    try {
      final db = await _openThumbDb();
      await _thumbStore.record(url).put(db, base64Encode(bytes));
    } catch (_) {}
  }

  // URLs en cours de génération — évite le travail dupliqué si deux widgets
  // demandent le même thumb en même temps.
  final Set<String> _thumbsInProgress = <String>{};

  Future<void> _generateAndStoreTinyThumb(String url, File file) async {
    if (_tinyThumbMemCache.containsKey(url)) return;
    if (!_thumbsInProgress.add(url)) return; // déjà en cours
    try {
      final bytes = await file.readAsBytes();
      // flutter_image_compress tourne sur un thread natif → n'impacte pas
      // le raster thread de Flutter ni le scroll.
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 24,
        minHeight: 24,
        quality: 40,
        format: CompressFormat.jpeg,
      );
      await _saveTinyThumb(url, compressed);
    } catch (_) {
    } finally {
      _thumbsInProgress.remove(url);
    }
  }

  Future<Database> _openThumbDb() {
    _thumbDbFuture ??= _initThumbDb();
    return _thumbDbFuture!;
  }

  Future<Database> _initThumbDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _thumbDbFileName);
    return databaseFactoryIo.openDatabase(dbPath);
  }

  // ── File-cache helpers ──────────────────────────────────────────────────────

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
      unawaited(_generateAndStoreTinyThumb(normalizedUrl, cached.file));
      return cached.file;
    }

    final downloaded = await _cacheManager.getSingleFile(normalizedUrl);
    _resolvedFiles[normalizedUrl] = downloaded;
    unawaited(_generateAndStoreTinyThumb(normalizedUrl, downloaded));
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
