import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'app_api_client.dart';
import 'cloudinary_image_url.dart';
import 'session_storage.dart';

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

  ConversationsApiService({AppApiClient? client})
    : _client = client ?? AppApiClient();

  final AppApiClient _client;
  final SessionStorage _sessionStorage = SessionStorage();

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final data = await _client.get('/conversations', authenticated: true);
    final normalized = (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    await _writeCacheValue(_conversationsListCacheKey, normalized);
    return normalized;
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
    String conversationId,
  ) async {
    final data = await _client.get(
      '/conversations/$conversationId',
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _writeCacheValue(
      '$_conversationByIdCachePrefix${conversationId.trim()}',
      normalized,
    );
    await _cacheConversationAliases(normalized, fallbackId: conversationId);
    return normalized;
  }

  Future<Map<String, dynamic>?> getCachedConversationById(
    String conversationId,
  ) async {
    return _readCachedConversation(
      '$_conversationByIdCachePrefix${conversationId.trim()}',
    );
  }

  Future<Map<String, dynamic>> fetchConversationForProduct(
    String productId,
  ) async {
    final data = await _client.get(
      '/conversations/product/$productId',
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _writeCacheValue(
      '$_conversationByProductCachePrefix${productId.trim()}',
      normalized,
    );
    await _cacheConversationAliases(normalized, fallbackProductId: productId);
    return normalized;
  }

  Future<Map<String, dynamic>?> getCachedConversationForProduct(
    String productId,
  ) async {
    return _readCachedConversation(
      '$_conversationByProductCachePrefix${productId.trim()}',
    );
  }

  Future<Map<String, dynamic>> fetchConversationForUser(
    String targetUserId,
  ) async {
    final data = await _client.get(
      '/conversations/user/$targetUserId',
      authenticated: true,
    );
    final normalized = Map<String, dynamic>.from(data as Map);
    await _writeCacheValue(
      '$_conversationByUserCachePrefix${targetUserId.trim()}',
      normalized,
    );
    await _cacheConversationAliases(normalized, fallbackUserId: targetUserId);
    return normalized;
  }

  Future<Map<String, dynamic>?> getCachedConversationForUser(
    String targetUserId,
  ) async {
    return _readCachedConversation(
      '$_conversationByUserCachePrefix${targetUserId.trim()}',
    );
  }

  Future<Map<String, dynamic>?> _readCachedConversation(String key) async {
    final cached = await _readCacheValue(key);
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
        unawaited(prefs.remove(key));
        return null;
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCacheValue(String key, Object data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }),
    );
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
    return Map<String, dynamic>.from(data as Map);
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
    return Map<String, dynamic>.from(data as Map);
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
    return Map<String, dynamic>.from(data as Map);
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
    return Map<String, dynamic>.from(data as Map);
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
    return Map<String, dynamic>.from(data as Map);
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
  }) {
    return _uploadAttachment(
      endpointPath: '/conversations/attachments/document',
      fileBytes: fileBytes,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  Future<Map<String, dynamic>> _uploadAttachment({
    required String endpointPath,
    required Uint8List fileBytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw AppApiException('Session invalide');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$endpointPath');
    final contentType = _resolveMultipartContentType(
      endpointPath: endpointPath,
      fileName: fileName,
    );
    final request =
        _ProgressMultipartRequest('POST', uri, onProgress: onProgress)
          ..headers['Authorization'] = 'Bearer $accessToken'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
              contentType: contentType,
            ),
          );

    final decoded = await _sendMultipartRequest(request);
    return Map<String, dynamic>.from(
      (decoded['data'] as Map?) ?? const <String, dynamic>{},
    );
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

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {this.onProgress});

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
          sentBytes += chunk.length;
          final progress = sentBytes / totalBytes;
          onProgress!(progress.clamp(0, 1).toDouble());
          sink.add(chunk);
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
