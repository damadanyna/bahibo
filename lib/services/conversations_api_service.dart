import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_api_client.dart';
import 'cloudinary_image_url.dart';
import 'local_conversation_store.dart';

class ConversationsApiService {
  static const String _conversationsListCacheKey =
      'BANAY.cache.conversations.list';
  static const String _conversationByIdCachePrefix =
      'BANAY.cache.conversations.by_id.';
  static const String _conversationByProductCachePrefix =
      'BANAY.cache.conversations.by_product.';
  static const String _conversationByUserCachePrefix =
      'BANAY.cache.conversations.by_user.';
  static const Duration _conversationCacheTtl = Duration(minutes: 8);
  static final Map<String, _ConversationCacheEntry> _memoryCache =
      <String, _ConversationCacheEntry>{};
  static final Map<String, Future<void>> _warmConversationRequests =
      <String, Future<void>>{};

  ConversationsApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;
  final LocalConversationStore _localConversationStore =
      LocalConversationStore.instance;

  Map<String, String>? _conversationQueryParameters({
    int? limit,
    String? beforeMessageId,
  }) {
    final parameters = <String, String>{};
    if (limit != null && limit > 0) {
      parameters['limit'] = limit.toString();
    }

    final normalizedBeforeMessageId = beforeMessageId?.trim() ?? '';
    if (normalizedBeforeMessageId.isNotEmpty) {
      parameters['beforeMessageId'] = normalizedBeforeMessageId;
    }

    return parameters.isEmpty ? null : parameters;
  }

  bool _shouldCacheConversationPage(String? beforeMessageId) {
    return (beforeMessageId?.trim().isEmpty ?? true);
  }

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final data = await _client.get('/conversations', authenticated: true);
    final normalized = (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    await _writeCacheValue(_conversationsListCacheKey, normalized);
    return normalized;
  }

  List<Map<String, dynamic>>? peekCachedConversations() {
    final cached = _peekCacheValue(_conversationsListCacheKey);
    if (cached is! List) {
      return null;
    }

    return cached
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>?> getCachedConversations() async {
    final cached = await _readCacheValue(_conversationsListCacheKey);
    if (cached is! List) {
      return null;
    }

    return cached
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchConversationById(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) async {
    final data = await _client.get(
      '/conversations/$conversationId',
      queryParameters: _conversationQueryParameters(
        limit: limit,
        beforeMessageId: beforeMessageId,
      ),
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackId: conversationId,
    );
    if (_shouldCacheConversationPage(beforeMessageId)) {
      await _writeCacheValue(
        '$_conversationByIdCachePrefix${conversationId.trim()}',
        normalized,
      );
      await _cacheConversationAliases(normalized, fallbackId: conversationId);
    }
    return normalized;
  }

  Future<Map<String, dynamic>?> getCachedConversationById(
    String conversationId,
  ) async {
    return _readCachedConversation(
      '$_conversationByIdCachePrefix${conversationId.trim()}',
    );
  }

  Future<Map<String, dynamic>?> getStoredConversationById(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) {
    return _localConversationStore.getConversationById(
      conversationId,
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Map<String, dynamic>? peekCachedConversationById(String conversationId) {
    return _peekCachedConversation(
      '$_conversationByIdCachePrefix${conversationId.trim()}',
    );
  }

  Future<Map<String, dynamic>> fetchConversationForProduct(
    String productId, {
    int? limit,
    String? beforeMessageId,
  }) async {
    final data = await _client.get(
      '/conversations/product/$productId',
      queryParameters: _conversationQueryParameters(
        limit: limit,
        beforeMessageId: beforeMessageId,
      ),
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackProductId: productId,
    );
    if (_shouldCacheConversationPage(beforeMessageId)) {
      await _writeCacheValue(
        '$_conversationByProductCachePrefix${productId.trim()}',
        normalized,
      );
      await _cacheConversationAliases(normalized, fallbackProductId: productId);
    }
    return normalized;
  }

  Future<Map<String, dynamic>?> getCachedConversationForProduct(
    String productId,
  ) async {
    return _readCachedConversation(
      '$_conversationByProductCachePrefix${productId.trim()}',
    );
  }

  Future<Map<String, dynamic>?> getStoredConversationForProduct(
    String productId, {
    int? limit,
    String? beforeMessageId,
  }) {
    return _localConversationStore.getConversationForProduct(
      productId,
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Map<String, dynamic>? peekCachedConversationForProduct(String productId) {
    return _peekCachedConversation(
      '$_conversationByProductCachePrefix${productId.trim()}',
    );
  }

  Future<Map<String, dynamic>> fetchConversationForUser(
    String targetUserId, {
    int? limit,
    String? beforeMessageId,
  }) async {
    final data = await _client.get(
      '/conversations/user/$targetUserId',
      queryParameters: _conversationQueryParameters(
        limit: limit,
        beforeMessageId: beforeMessageId,
      ),
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackUserId: targetUserId,
    );
    if (_shouldCacheConversationPage(beforeMessageId)) {
      await _writeCacheValue(
        '$_conversationByUserCachePrefix${targetUserId.trim()}',
        normalized,
      );
      await _cacheConversationAliases(normalized, fallbackUserId: targetUserId);
    }
    return normalized;
  }

  Future<Map<String, dynamic>?> getCachedConversationForUser(
    String targetUserId,
  ) async {
    return _readCachedConversation(
      '$_conversationByUserCachePrefix${targetUserId.trim()}',
    );
  }

  Future<Map<String, dynamic>?> getStoredConversationForUser(
    String targetUserId, {
    int? limit,
    String? beforeMessageId,
  }) {
    return _localConversationStore.getConversationForUser(
      targetUserId,
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Map<String, dynamic>? peekCachedConversationForUser(String targetUserId) {
    return _peekCachedConversation(
      '$_conversationByUserCachePrefix${targetUserId.trim()}',
    );
  }

  Future<void> warmConversationById(String conversationId, {int limit = 8}) {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) {
      return Future.value();
    }

    final cacheKey = '$_conversationByIdCachePrefix$normalizedConversationId';
    if (_peekCacheValue(cacheKey) != null) {
      return Future.value();
    }

    final requestKey = '$cacheKey|$limit';
    final inFlight = _warmConversationRequests[requestKey];
    if (inFlight != null) {
      return inFlight;
    }

    final request =
        fetchConversationById(
          normalizedConversationId,
          limit: limit,
        ).then((_) {}).catchError((_) {}).whenComplete(() {
          _warmConversationRequests.remove(requestKey);
        });

    _warmConversationRequests[requestKey] = request;
    return request;
  }

  Future<Map<String, dynamic>?> _readCachedConversation(String key) async {
    final cached = await _readCacheValue(key);
    if (cached is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(cached);
  }

  Map<String, dynamic>? _peekCachedConversation(String key) {
    final cached = _peekCacheValue(key);
    if (cached is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(cached);
  }

  Future<void> _cacheConversationAliases(
    Map<String, dynamic> conversation, {
    String? fallbackId,
    String? fallbackProductId,
    String? fallbackUserId,
  }) async {
    final conversationId =
        conversation['id']?.toString().trim() ?? fallbackId?.trim() ?? '';
    if (conversationId.isNotEmpty) {
      await _writeCacheValue(
        '$_conversationByIdCachePrefix$conversationId',
        conversation,
      );
    }

    final product = conversation['product'];
    final productId = product is Map
        ? product['id']?.toString().trim() ?? fallbackProductId?.trim() ?? ''
        : fallbackProductId?.trim() ?? '';
    if (productId.isNotEmpty) {
      await _writeCacheValue(
        '$_conversationByProductCachePrefix$productId',
        conversation,
      );
    }

    final participant = conversation['participant'];
    final userId = participant is Map
        ? participant['id']?.toString().trim() ?? fallbackUserId?.trim() ?? ''
        : fallbackUserId?.trim() ?? '';
    if (userId.isNotEmpty) {
      await _writeCacheValue(
        '$_conversationByUserCachePrefix$userId',
        conversation,
      );
    }
  }

  Future<dynamic> _readCacheValue(String key) async {
    final inMemory = _peekCacheValue(key);
    if (inMemory != null) {
      return inMemory;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final cachedAtMillis = (decoded['cachedAt'] as num?)?.toInt();
      final data = decoded['data'];
      if (cachedAtMillis == null || data == null) {
        return null;
      }

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMillis);
      if (DateTime.now().difference(cachedAt) > _conversationCacheTtl) {
        _memoryCache.remove(key);
        unawaited(prefs.remove(key));
        return null;
      }

      _writeMemoryCacheValue(key, data, cachedAt: cachedAt);
      return data;
    } catch (_) {
      return null;
    }
  }

  dynamic _peekCacheValue(String key) {
    final entry = _memoryCache[key];
    if (entry == null) {
      return null;
    }

    if (DateTime.now().difference(entry.cachedAt) > _conversationCacheTtl) {
      _memoryCache.remove(key);
      return null;
    }

    return _cloneCacheData(entry.data);
  }

  Future<void> _writeCacheValue(String key, Object data) async {
    _writeMemoryCacheValue(key, data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }),
    );
  }

  void _writeMemoryCacheValue(String key, Object data, {DateTime? cachedAt}) {
    _memoryCache[key] = _ConversationCacheEntry(
      cachedAt: cachedAt ?? DateTime.now(),
      data: _cloneCacheData(data),
    );
  }

  dynamic _cloneCacheData(Object? data) {
    if (data == null) {
      return null;
    }

    return jsonDecode(jsonEncode(data));
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String content,
    Map<String, dynamic>? reply,
  }) async {
    final data = await _client.post(
      '/conversations/$conversationId/messages',
      body: {'content': content, if (reply != null) ...reply},
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackId: conversationId,
    );
    return normalized;
  }

  Future<Map<String, dynamic>> sendProductMessage({
    required String productId,
    required String content,
    Map<String, dynamic>? reply,
  }) async {
    final data = await _client.post(
      '/conversations/product/$productId/messages',
      body: {'content': content, if (reply != null) ...reply},
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackProductId: productId,
    );
    return normalized;
  }

  Future<Map<String, dynamic>> sendUserMessage({
    required String targetUserId,
    required String content,
    Map<String, dynamic>? productSnapshot,
    Map<String, dynamic>? reply,
  }) async {
    final data = await _client.post(
      '/conversations/user/$targetUserId/messages',
      body: {
        'content': content,
        if (productSnapshot != null) ...productSnapshot,
        if (reply != null) ...reply,
      },
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackUserId: targetUserId,
    );
    return normalized;
  }

  Future<Map<String, dynamic>> sendMediaMessage({
    required String conversationId,
    required Map<String, dynamic> mediaPayload,
    Map<String, dynamic>? reply,
  }) async {
    final data = await _client.post(
      '/conversations/$conversationId/media-messages',
      body: {...mediaPayload, if (reply != null) ...reply},
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackId: conversationId,
    );
    return normalized;
  }

  Future<Map<String, dynamic>> sendProductMediaMessage({
    required String productId,
    required Map<String, dynamic> mediaPayload,
    Map<String, dynamic>? reply,
  }) async {
    final data = await _client.post(
      '/conversations/product/$productId/media-messages',
      body: {...mediaPayload, if (reply != null) ...reply},
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackProductId: productId,
    );
    return normalized;
  }

  Future<Map<String, dynamic>> sendUserMediaMessage({
    required String targetUserId,
    required Map<String, dynamic> mediaPayload,
    Map<String, dynamic>? reply,
  }) async {
    final data = await _client.post(
      '/conversations/user/$targetUserId/media-messages',
      body: {...mediaPayload, if (reply != null) ...reply},
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _localConversationStore.saveConversationSnapshot(
      normalized,
      fallbackUserId: targetUserId,
    );
    return normalized;
  }

  Future<Map<String, dynamic>> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final data = await _client.delete(
      '/conversations/$conversationId/messages/$messageId',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> markConversationRead({
    required String conversationId,
  }) async {
    final data = await _client.post(
      '/conversations/$conversationId/read',
      authenticated: true,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadPhotoAttachment({
    required Uint8List fileBytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final signature = await _client.post(
      '/conversations/attachments/photo/direct-signature',
      authenticated: true,
    );
    final signatureData = Map<String, dynamic>.from(signature as Map);
    final cloudName = signatureData['cloudName']?.toString().trim() ?? '';
    final apiKey = signatureData['apiKey']?.toString().trim() ?? '';
    final folder = signatureData['folder']?.toString().trim() ?? '';
    final publicId = signatureData['publicId']?.toString().trim() ?? '';
    final signatureValue = signatureData['signature']?.toString().trim() ?? '';
    final timestamp = signatureData['timestamp'];
    if (cloudName.isEmpty ||
        apiKey.isEmpty ||
        folder.isEmpty ||
        publicId.isEmpty ||
        signatureValue.isEmpty ||
        timestamp == null) {
      throw AppApiException('Signature Cloudinary invalide');
    }

    final uploadUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final contentType = _resolveMultipartContentType(
      endpointPath: '/conversations/attachments/photo',
      fileName: fileName,
    );
    final request =
        _ProgressMultipartRequest('POST', uploadUri, onProgress: onProgress)
          ..fields.addAll({
            'api_key': apiKey,
            'timestamp': timestamp.toString(),
            'folder': folder,
            'public_id': publicId,
            'overwrite': 'true',
            'signature': signatureValue,
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
              contentType: contentType,
            ),
          );

    final response = await _sendMultipartRequest(request);
    final secureUrl = response['secure_url']?.toString().trim() ?? '';
    final transformedUrl = CloudinaryImageUrl.forChatMessage(secureUrl);
    if (secureUrl.isEmpty || transformedUrl.isEmpty) {
      throw AppApiException('Upload Cloudinary incomplet');
    }

    return {
      'attachmentType': 'photo',
      'fileName': fileName,
      'attachmentUrl': transformedUrl,
      'originalUrl': secureUrl,
      'publicId': response['public_id']?.toString(),
    };
  }

  Future<Map<String, dynamic>> uploadDocumentAttachment({
    required Uint8List fileBytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final signature = await _client.post(
      '/conversations/attachments/document/direct-signature',
      authenticated: true,
    );
    final signatureData = Map<String, dynamic>.from(signature as Map);
    final cloudName = signatureData['cloudName']?.toString().trim() ?? '';
    final apiKey = signatureData['apiKey']?.toString().trim() ?? '';
    final folder = signatureData['folder']?.toString().trim() ?? '';
    final publicId = signatureData['publicId']?.toString().trim() ?? '';
    final signatureValue = signatureData['signature']?.toString().trim() ?? '';
    final timestamp = signatureData['timestamp'];
    if (cloudName.isEmpty ||
        apiKey.isEmpty ||
        folder.isEmpty ||
        publicId.isEmpty ||
        signatureValue.isEmpty ||
        timestamp == null) {
      throw AppApiException('Signature Cloudinary invalide');
    }

    final uploadUri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/raw/upload',
    );
    final contentType = _resolveMultipartContentType(
      endpointPath: '/conversations/attachments/document',
      fileName: fileName,
    );
    final request =
        _ProgressMultipartRequest('POST', uploadUri, onProgress: onProgress)
          ..fields.addAll({
            'api_key': apiKey,
            'timestamp': timestamp.toString(),
            'folder': folder,
            'public_id': publicId,
            'overwrite': 'true',
            'signature': signatureValue,
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
              contentType: contentType,
            ),
          );

    final response = await _sendMultipartRequest(request);
    final secureUrl = response['secure_url']?.toString().trim() ?? '';
    if (secureUrl.isEmpty) {
      throw AppApiException('Upload Cloudinary incomplet');
    }

    return {
      'attachmentType': 'document',
      'fileName': fileName,
      'attachmentUrl': secureUrl,
      'originalUrl': secureUrl,
      'publicId': response['public_id']?.toString(),
    };
  }

  Future<Map<String, dynamic>> _sendMultipartRequest(
    http.MultipartRequest request,
  ) async {
    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await request.send();
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur BANAY');
    }

    final response = await http.Response.fromStream(streamedResponse);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['error'] is Map)
          ? (decoded['error'] as Map)['message']?.toString()
          : decoded['message']?.toString();
      throw AppApiException(
        (message == null || message.trim().isEmpty)
            ? 'Erreur serveur'
            : message.trim(),
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  MediaType _resolveMultipartContentType({
    required String endpointPath,
    required String fileName,
  }) {
    final extension = _fileExtension(fileName);
    if (endpointPath.endsWith('/photo')) {
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          return MediaType('image', 'jpeg');
        case 'png':
          return MediaType('image', 'png');
        case 'webp':
          return MediaType('image', 'webp');
        case 'heic':
          return MediaType('image', 'heic');
        case 'heif':
          return MediaType('image', 'heif');
      }
      return MediaType('image', 'jpeg');
    }

    switch (extension) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'txt':
        return MediaType('text', 'plain');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  String _fileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot < 0 || lastDot == fileName.length - 1) {
      return '';
    }

    return fileName.substring(lastDot + 1).toLowerCase();
  }
}

class _ConversationCacheEntry {
  const _ConversationCacheEntry({required this.cachedAt, required this.data});

  final DateTime cachedAt;
  final dynamic data;
}

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {this.onProgress});

  static const int _progressChunkSize = 16 * 1024;

  final void Function(double progress)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final totalBytes = contentLength;

    if (onProgress == null || totalBytes <= 0) {
      return byteStream;
    }

    var sentBytes = 0;
    onProgress!(0);

    final progressStream = byteStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          if (chunk.isEmpty) {
            return;
          }

          for (
            var offset = 0;
            offset < chunk.length;
            offset += _progressChunkSize
          ) {
            final end = math.min(offset + _progressChunkSize, chunk.length);
            final slice = chunk.sublist(offset, end);
            sentBytes += slice.length;
            final progress = sentBytes / totalBytes;
            onProgress!(progress.clamp(0, 1).toDouble());
            sink.add(slice);
          }
        },
        handleDone: (sink) {
          onProgress!(1);
          sink.close();
        },
      ),
    );

    return http.ByteStream(progressStream);
  }
}
