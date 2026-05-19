import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';
import 'app_api_client.dart';
import 'app_logger.dart';

class ChatDocumentOpenResult {
  const ChatDocumentOpenResult._({
    required this.opened,
    this.errorMessage,
    this.statusCode,
  });

  const ChatDocumentOpenResult.success()
    : this._(opened: true, errorMessage: null, statusCode: null);

  const ChatDocumentOpenResult.failure({
    required String message,
    int? statusCode,
  }) : this._(opened: false, errorMessage: message, statusCode: statusCode);

  final bool opened;
  final String? errorMessage;
  final int? statusCode;
}

class ChatDocumentOpenService {
  ChatDocumentOpenService._();

  static final ChatDocumentOpenService instance = ChatDocumentOpenService._();

  static const String _logTag = 'ChatDocumentOpenService';
  static const MethodChannel _fileOpenerChannel = MethodChannel(
    'banay/file_opener',
  );

  final AppApiClient _appApiClient = AppApiClient();

  Future<ChatDocumentOpenResult> openRemoteDocument(
    String documentUrl, {
    String? fileName,
    String? mimeType,
    String chooserTitle = 'Ouvrir avec',
  }) async {
    final normalizedUrl = documentUrl.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return const ChatDocumentOpenResult.failure(
        message: 'Lien du document invalide.',
      );
    }

    try {
      var resolvedFileName = _resolveAttachmentFileName(
        uri,
        fileName: fileName,
        mimeType: mimeType,
      );
      var resolvedMimeType = _resolveAttachmentMimeType(
        resolvedFileName,
        mimeType,
      );

      final cachedDirectory = await _documentCacheDirectory();
      final cacheKey = _stableCacheKey(uri.toString());
      final cachedFile = await _resolveCachedDocumentFile(
        cachedDirectory,
        cacheKey: cacheKey,
        fileName: resolvedFileName,
      );

      if (!await cachedFile.exists() || await cachedFile.length() == 0) {
        final response = await _downloadDocumentResponse(uri);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          AppLogger.warning(
            _logTag,
            'Document download failed for $uri with HTTP ${response.statusCode}',
          );
          return ChatDocumentOpenResult.failure(
            message:
                'Impossible de preparer ce document. HTTP ${response.statusCode}.',
            statusCode: response.statusCode,
          );
        }

        final headerFileName = _extractFileNameFromResponseHeaders(response);
        if (headerFileName != null && headerFileName.trim().isNotEmpty) {
          resolvedFileName = headerFileName.trim();
        }
        resolvedMimeType =
            _extractMimeTypeFromResponseHeaders(response) ??
            _resolveAttachmentMimeType(resolvedFileName, mimeType);

        final targetFile = await _resolveCachedDocumentFile(
          cachedDirectory,
          cacheKey: cacheKey,
          fileName: resolvedFileName,
          clearStaleVariants: true,
        );
        await targetFile.writeAsBytes(response.bodyBytes, flush: true);
        final opened = await _openLocalFile(
          targetFile,
          mimeType: resolvedMimeType,
          chooserTitle: chooserTitle,
        );
        if (opened) {
          return const ChatDocumentOpenResult.success();
        }

        return const ChatDocumentOpenResult.failure(
          message: 'Impossible d\'ouvrir le fichier localement.',
        );
      }

      final opened = await _openLocalFile(
        cachedFile,
        mimeType: resolvedMimeType,
        chooserTitle: chooserTitle,
      );
      if (opened) {
        return const ChatDocumentOpenResult.success();
      }

      return const ChatDocumentOpenResult.failure(
        message: 'Impossible d\'ouvrir le fichier localement.',
      );
    } on SocketException catch (error, stackTrace) {
      AppLogger.error(
        _logTag,
        'Document open failed with network error for $uri',
        error,
        stackTrace,
      );
      return const ChatDocumentOpenResult.failure(
        message: 'Impossible de telecharger le fichier. Verifie la connexion.',
      );
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error(
        _logTag,
        'Document open failed on native file chooser for $uri',
        error,
        stackTrace,
      );
      final details = error.code.trim();
      return ChatDocumentOpenResult.failure(
        message: details.isEmpty
            ? 'Impossible d\'ouvrir le fichier localement.'
            : 'Impossible d\'ouvrir le fichier localement ($details).',
      );
    } on MissingPluginException catch (error, stackTrace) {
      AppLogger.error(
        _logTag,
        'Document open failed because the native plugin path is unavailable for $uri',
        error,
        stackTrace,
      );
      return const ChatDocumentOpenResult.failure(
        message:
            'Ouverture locale indisponible. Redemarre completement l\'application Android.',
      );
    } on FileSystemException catch (error, stackTrace) {
      AppLogger.error(
        _logTag,
        'Document open failed while preparing the cached local file for $uri',
        error,
        stackTrace,
      );
      return const ChatDocumentOpenResult.failure(
        message:
            'Impossible de preparer le fichier local. Verifie l\'espace de stockage.',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        _logTag,
        'Document open failed for $uri',
        error,
        stackTrace,
      );
      return const ChatDocumentOpenResult.failure(
        message:
            'Impossible de preparer ce document pour une ouverture locale.',
      );
    }
  }

  Future<Directory> _documentCacheDirectory() async {
    final cacheDirectory = await getApplicationDocumentsDirectory();
    final documentsDirectory = Directory(
      path.join(cacheDirectory.path, 'chat_documents'),
    );
    if (!documentsDirectory.existsSync()) {
      documentsDirectory.createSync(recursive: true);
    }
    return documentsDirectory;
  }

  Future<File> _resolveCachedDocumentFile(
    Directory directory, {
    required String cacheKey,
    required String fileName,
    bool clearStaleVariants = false,
  }) async {
    final sanitizedFileName = _sanitizeAttachmentFileName(fileName);
    final expectedPath = path.join(
      directory.path,
      '${cacheKey}_$sanitizedFileName',
    );
    final expectedFile = File(expectedPath);

    final staleVariants = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => path.basename(file.path).startsWith('${cacheKey}_'))
        .toList();

    if (clearStaleVariants) {
      for (final staleFile in staleVariants) {
        if (staleFile.path == expectedPath) {
          continue;
        }
        try {
          await staleFile.delete();
        } catch (_) {
          // Ignore cleanup failures; the current target file can still be used.
        }
      }
      return expectedFile;
    }

    final matchingExisting = staleVariants.where(
      (file) => file.path == expectedPath,
    );
    if (matchingExisting.isNotEmpty) {
      return matchingExisting.first;
    }

    if (staleVariants.isNotEmpty) {
      return staleVariants.first;
    }

    return expectedFile;
  }

  Future<http.Response> _downloadDocumentResponse(Uri uri) async {
    if (_shouldAttachDocumentAuthHeader(uri)) {
      return _appApiClient.getRawUri(uri, authenticated: true);
    }

    return http.get(uri, headers: const <String, String>{'Accept': '*/*'});
  }

  Future<bool> _openLocalFile(
    File file, {
    required String mimeType,
    required String chooserTitle,
  }) async {
    if (!await file.exists()) {
      return false;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final opened = await _fileOpenerChannel.invokeMethod<bool>(
        'openFileWithChooser',
        <String, dynamic>{
          'path': file.path,
          'mimeType': mimeType,
          'title': chooserTitle,
        },
      );
      return opened == true;
    }

    final fileUri = Uri.file(file.path);
    return launchUrl(fileUri, mode: LaunchMode.externalApplication);
  }

  bool _shouldAttachDocumentAuthHeader(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    final documentHost = uri.host.trim().toLowerCase();
    if (documentHost.isEmpty) {
      return false;
    }

    final apiHost = Uri.parse(ApiConfig.baseUrl).host.trim().toLowerCase();
    return documentHost == apiHost;
  }

  String _resolveAttachmentFileName(
    Uri uri, {
    String? fileName,
    String? mimeType,
  }) {
    final trimmedFileName = fileName?.trim() ?? '';
    if (trimmedFileName.isNotEmpty) {
      return trimmedFileName;
    }

    final uriFileName = path.basename(uri.path).trim();
    if (uriFileName.isNotEmpty) {
      return uriFileName;
    }

    final extension = _fileExtensionFromMimeType(mimeType);
    return extension == null ? 'document' : 'document.$extension';
  }

  String _sanitizeAttachmentFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return sanitized.isEmpty ? 'document' : sanitized;
  }

  String _stableCacheKey(String input) {
    var hash = 0;
    for (final codeUnit in utf8.encode(input)) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String? _extractFileNameFromResponseHeaders(http.Response response) {
    final contentDisposition = response.headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'content-disposition',
          orElse: () => const MapEntry<String, String>('', ''),
        )
        .value;
    if (contentDisposition.isEmpty) {
      return null;
    }

    final encodedMatch = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (encodedMatch != null) {
      return Uri.decodeComponent(encodedMatch.group(1)!.trim());
    }

    final plainMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (plainMatch != null) {
      return plainMatch.group(1)?.trim();
    }

    return null;
  }

  String? _extractMimeTypeFromResponseHeaders(http.Response response) {
    final contentType = response.headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry<String, String>('', ''),
        )
        .value;
    if (contentType.isEmpty) {
      return null;
    }

    final normalized = contentType.split(';').first.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'application/octet-stream') {
      return null;
    }
    return normalized;
  }

  String _resolveAttachmentMimeType(String fileName, String? mimeType) {
    final trimmedMimeType = mimeType?.trim() ?? '';
    if (trimmedMimeType.isNotEmpty) {
      return trimmedMimeType;
    }

    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.zip':
        return 'application/zip';
      case '.rar':
        return 'application/vnd.rar';
      case '.7z':
        return 'application/x-7z-compressed';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.xml':
        return 'application/xml';
      case '.html':
        return 'text/html';
      case '.md':
        return 'text/markdown';
      case '.rtf':
        return 'application/rtf';
      default:
        return 'application/octet-stream';
    }
  }

  String? _fileExtensionFromMimeType(String? mimeType) {
    switch (mimeType?.trim().toLowerCase()) {
      case 'application/pdf':
        return 'pdf';
      case 'text/plain':
        return 'txt';
      case 'application/zip':
        return 'zip';
      case 'application/vnd.rar':
        return 'rar';
      case 'application/x-7z-compressed':
        return '7z';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'application/vnd.ms-powerpoint':
        return 'ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';
      case 'text/csv':
        return 'csv';
      case 'application/json':
        return 'json';
      case 'application/xml':
        return 'xml';
      case 'text/html':
        return 'html';
      case 'text/markdown':
        return 'md';
      case 'application/rtf':
        return 'rtf';
      default:
        return null;
    }
  }
}
