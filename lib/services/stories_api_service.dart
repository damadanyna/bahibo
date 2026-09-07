import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'app_api_client.dart';
import 'app_logger.dart';
import 'session_storage.dart';

enum StoryMediaType { image, video }

/// Bytes handed to the socket so far, out of the file size.
typedef StoryUploadProgressCallback =
    void Function(int sentBytes, int totalBytes);

/// One photo or short video published by an account, visible for 24 h.
class StoryItem {
  const StoryItem({
    required this.id,
    required this.authorUserId,
    required this.mediaType,
    required this.mediaUrl,
    this.originalMediaUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.isViewed,
    required this.isOwner,
    required this.viewCount,
  });

  final String id;
  final String authorUserId;
  final StoryMediaType mediaType;

  /// Videos: the optimized playback rendition served by the backend.
  final String mediaUrl;

  /// Videos: the file as uploaded, only used when the rendition cannot be
  /// played yet (see [fallbackMediaUrl]). Null for photos.
  final String? originalMediaUrl;

  /// Poster frame for videos; the image itself for photos.
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isViewed;
  final bool isOwner;

  /// Only filled for the owner's own stories.
  final int? viewCount;

  bool get isVideo => mediaType == StoryMediaType.video;

  String get posterUrl =>
      thumbnailUrl?.trim().isNotEmpty == true ? thumbnailUrl!.trim() : mediaUrl;

  /// Heavier source to try when [mediaUrl] fails; null when there is none
  /// worth trying.
  String? get fallbackMediaUrl {
    final original = originalMediaUrl?.trim() ?? '';
    return original.isEmpty || original == mediaUrl ? null : original;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryItem.fromMap(Map<String, dynamic> map) {
    final rawMediaType = map['mediaType']?.toString().trim().toUpperCase();
    return StoryItem(
      id: map['id']?.toString() ?? '',
      authorUserId: map['authorUserId']?.toString() ?? '',
      mediaType: rawMediaType == 'VIDEO'
          ? StoryMediaType.video
          : StoryMediaType.image,
      // `imageUrl` was the field name of the photo-only backend.
      mediaUrl:
          map['mediaUrl']?.toString() ?? map['imageUrl']?.toString() ?? '',
      originalMediaUrl: map['originalMediaUrl']?.toString(),
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      caption: map['caption']?.toString().trim().isNotEmpty == true
          ? map['caption'].toString().trim()
          : null,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(map['expiresAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now().add(const Duration(hours: 24)),
      isViewed: map['isViewed'] == true,
      isOwner: map['isOwner'] == true,
      viewCount: (map['viewCount'] as num?)?.toInt(),
    );
  }

  StoryItem copyWith({bool? isViewed, int? viewCount}) {
    return StoryItem(
      id: id,
      authorUserId: authorUserId,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      originalMediaUrl: originalMediaUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      caption: caption,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isViewed: isViewed ?? this.isViewed,
      isOwner: isOwner,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}

/// All active stories of one account, in publication order.
class StoryGroup {
  const StoryGroup({
    required this.authorUserId,
    required this.authorSellerProfileId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.isOwner,
    required this.stories,
  });

  final String authorUserId;

  /// Null for customers.
  final String? authorSellerProfileId;
  final String authorName;
  final String authorAvatarUrl;
  final bool isOwner;
  final List<StoryItem> stories;

  bool get hasUnviewed => stories.any((story) => !story.isViewed);

  StoryItem? get latestStory => stories.isEmpty ? null : stories.last;

  /// Index of the first story not seen yet, so tapping a ring resumes
  /// where the viewer left off (0 when everything is already seen).
  int get firstUnviewedIndex {
    final index = stories.indexWhere((story) => !story.isViewed);
    return index < 0 ? 0 : index;
  }

  factory StoryGroup.fromMap(Map<String, dynamic> map) {
    final rawStories = (map['stories'] as List?) ?? const [];
    final sellerProfileId = map['authorSellerProfileId']?.toString().trim();
    return StoryGroup(
      authorUserId: map['authorUserId']?.toString() ?? '',
      authorSellerProfileId: sellerProfileId == null || sellerProfileId.isEmpty
          ? null
          : sellerProfileId,
      authorName: map['authorName']?.toString() ?? '',
      authorAvatarUrl: map['authorAvatarUrl']?.toString() ?? '',
      isOwner: map['isOwner'] == true,
      stories: rawStories
          .whereType<Map>()
          .map((item) => StoryItem.fromMap(Map<String, dynamic>.from(item)))
          .where((story) => story.id.isNotEmpty && story.mediaUrl.isNotEmpty)
          .toList(),
    );
  }

  StoryGroup copyWith({List<StoryItem>? stories}) {
    return StoryGroup(
      authorUserId: authorUserId,
      authorSellerProfileId: authorSellerProfileId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      isOwner: isOwner,
      stories: stories ?? this.stories,
    );
  }
}

class StoriesApiService {
  StoriesApiService({AppApiClient? client, SessionStorage? sessionStorage})
    : _client = client ?? AppApiClient(),
      _sessionStorage = sessionStorage ?? SessionStorage();

  static const String _tag = 'StoriesApiService';

  final AppApiClient _client;
  final SessionStorage _sessionStorage;

  /// Publishes a story with the media sent **straight from the phone to
  /// Cloudinary** (signature from the backend, upload, then a small confirm
  /// call), so the file no longer transits through the BANAY server and
  /// 100 % really means the transfer is over. Falls back to the
  /// server-relayed [createStory] on a backend without the direct route
  /// yet, or when Cloudinary cannot be reached from the phone.
  Future<StoryItem> publishStory({
    required File mediaFile,
    required StoryMediaType mediaType,
    String? caption,
    int? durationSeconds,
    StoryUploadProgressCallback? onUploadProgress,
  }) async {
    Map<String, dynamic> signature;
    try {
      final data = await _client.post(
        '/stories/direct-signature',
        body: {
          'mediaType': mediaType == StoryMediaType.video ? 'VIDEO' : 'IMAGE',
        },
        authenticated: true,
      );
      signature = Map<String, dynamic>.from((data as Map?) ?? const {});
    } on AppApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 501) {
        AppLogger.warning(_tag, 'Direct story upload unavailable, relaying');
        return createStory(
          mediaFile: mediaFile,
          mediaType: mediaType,
          caption: caption,
          durationSeconds: durationSeconds,
          onUploadProgress: onUploadProgress,
        );
      }
      rethrow;
    }

    Map<String, dynamic> upload;
    try {
      upload = await _uploadToCloudinary(
        mediaFile: mediaFile,
        mediaType: mediaType,
        signature: signature,
        onUploadProgress: onUploadProgress,
      );
    } on AppApiException catch (error) {
      if (error.statusCode != null) {
        rethrow;
      }
      // No route to Cloudinary from here (blocked or offline): the server
      // may still reach it.
      AppLogger.warning(_tag, 'Cloudinary unreachable, relaying', error);
      return createStory(
        mediaFile: mediaFile,
        mediaType: mediaType,
        caption: caption,
        durationSeconds: durationSeconds,
        onUploadProgress: onUploadProgress,
      );
    }

    final normalizedCaption = caption?.trim() ?? '';
    final data = await _client.post(
      '/stories/direct',
      body: {
        'mediaType': mediaType == StoryMediaType.video ? 'VIDEO' : 'IMAGE',
        'publicId': upload['public_id']?.toString() ?? '',
        'version': upload['version'],
        'signature': upload['signature']?.toString() ?? '',
        if (upload['format'] is String) 'format': upload['format'],
        if (durationSeconds != null && durationSeconds > 0)
          'durationSeconds': durationSeconds,
        if (normalizedCaption.isNotEmpty) 'caption': normalizedCaption,
      },
      authenticated: true,
    );
    return StoryItem.fromMap(
      Map<String, dynamic>.from((data as Map?) ?? const <String, dynamic>{}),
    );
  }

  /// Multipart POST to Cloudinary's upload API with the signed fields
  /// forwarded verbatim. Progress is the file's bytes handed to the socket.
  Future<Map<String, dynamic>> _uploadToCloudinary({
    required File mediaFile,
    required StoryMediaType mediaType,
    required Map<String, dynamic> signature,
    StoryUploadProgressCallback? onUploadProgress,
  }) async {
    final cloudName = signature['cloudName']?.toString().trim() ?? '';
    final resourceType = signature['resourceType']?.toString().trim() ?? '';
    final rawFields = signature['fields'];
    if (cloudName.isEmpty || resourceType.isEmpty || rawFields is! Map) {
      throw AppApiException('Signature Cloudinary invalide', statusCode: 500);
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
    );
    final request = http.MultipartRequest('POST', uri);
    rawFields.forEach((key, value) {
      request.fields[key.toString()] = value.toString();
    });
    request.files.add(
      await _trackedMultipartFile(
        'file',
        mediaFile,
        mediaType,
        onUploadProgress,
      ),
    );

    http.Response response;
    try {
      final streamedResponse = await request.send();
      response = await http.Response.fromStream(streamedResponse);
    } catch (_) {
      throw AppApiException('Impossible de joindre Cloudinary');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AppApiException(
        'Réponse invalide de Cloudinary (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map ? error['message']?.toString() : null;
      throw AppApiException(
        message == null || message.trim().isEmpty
            ? 'Envoi vers Cloudinary refusé (HTTP ${response.statusCode}).'
            : message.trim(),
        statusCode: response.statusCode,
      );
    }
    if (decoded['public_id'] is! String || decoded['signature'] is! String) {
      throw AppApiException('Upload Cloudinary incomplet', statusCode: 500);
    }
    return decoded;
  }

  /// The file stream wrapped to report progress the same way product
  /// uploads do, typed so the receiver does not have to guess from the
  /// extension.
  Future<http.MultipartFile> _trackedMultipartFile(
    String field,
    File mediaFile,
    StoryMediaType mediaType,
    StoryUploadProgressCallback? onUploadProgress,
  ) async {
    final totalBytes = await mediaFile.length();
    var sentBytes = 0;
    final trackedStream = mediaFile.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sentBytes += chunk.length;
          onUploadProgress?.call(sentBytes, totalBytes);
          sink.add(chunk);
        },
      ),
    );
    final fileName = mediaFile.uri.pathSegments.isNotEmpty
        ? mediaFile.uri.pathSegments.last
        : (mediaType == StoryMediaType.video ? 'story.mp4' : 'story.jpg');

    return http.MultipartFile(
      field,
      http.ByteStream(trackedStream),
      totalBytes,
      filename: fileName,
      contentType: _mediaTypeForPath(mediaFile.path, mediaType),
    );
  }

  Future<List<StoryGroup>> fetchStoryFeed() async {
    final data = await _client.get('/stories/feed', authenticated: true);
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((item) => StoryGroup.fromMap(Map<String, dynamic>.from(item)))
        .where((group) => group.stories.isNotEmpty)
        .toList();
  }

  /// Multipart upload (part `media` + `mediaType`, optional `caption` and
  /// `durationSeconds`). The file stream is wrapped to report progress the
  /// same way product uploads do.
  Future<StoryItem> createStory({
    required File mediaFile,
    required StoryMediaType mediaType,
    String? caption,
    int? durationSeconds,
    StoryUploadProgressCallback? onUploadProgress,
  }) async {
    final accessToken = await _sessionStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw AppApiException('Session utilisateur introuvable');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/stories');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['mediaType'] = mediaType == StoryMediaType.video
          ? 'VIDEO'
          : 'IMAGE';

    final normalizedCaption = caption?.trim() ?? '';
    if (normalizedCaption.isNotEmpty) {
      request.fields['caption'] = normalizedCaption;
    }
    if (durationSeconds != null && durationSeconds > 0) {
      request.fields['durationSeconds'] = '$durationSeconds';
    }

    request.files.add(
      await _trackedMultipartFile(
        'media',
        mediaFile,
        mediaType,
        onUploadProgress,
      ),
    );

    http.StreamedResponse streamedResponse;
    http.Response response;
    try {
      streamedResponse = await request.send();
      response = await http.Response.fromStream(streamedResponse);
    } catch (_) {
      throw AppApiException('Impossible de joindre le serveur BANAY');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AppApiException(
        'Réponse invalide du serveur (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded['message'] as String?) ?? 'Erreur serveur';
      throw AppApiException(message, statusCode: response.statusCode);
    }

    return StoryItem.fromMap(
      Map<String, dynamic>.from(
        (decoded['data'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  static MediaType _mediaTypeForPath(String path, StoryMediaType mediaType) {
    final extension = path.split('.').last.toLowerCase();
    if (mediaType == StoryMediaType.video) {
      switch (extension) {
        case 'mov':
          return MediaType('video', 'quicktime');
        case 'webm':
          return MediaType('video', 'webm');
        case '3gp':
          return MediaType('video', '3gpp');
        default:
          return MediaType('video', 'mp4');
      }
    }
    switch (extension) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      default:
        // image_picker re-encodes to JPEG when imageQuality is set.
        return MediaType('image', 'jpeg');
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    await _client.post('/stories/$storyId/view', authenticated: true);
  }

  Future<void> deleteStory(String storyId) async {
    await _client.delete('/stories/$storyId', authenticated: true);
  }

  Future<List<Map<String, dynamic>>> fetchStoryViewers(String storyId) async {
    final data = await _client.get(
      '/stories/$storyId/viewers',
      authenticated: true,
    );
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
