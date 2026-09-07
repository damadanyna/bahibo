import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';
import 'app_api_client.dart';
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
  final String mediaUrl;

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

  final AppApiClient _client;
  final SessionStorage _sessionStorage;

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

    // Without an explicit type the part is sent as application/octet-stream
    // and the backend has to guess from the extension.
    request.files.add(
      http.MultipartFile(
        'media',
        http.ByteStream(trackedStream),
        totalBytes,
        filename: fileName,
        contentType: _mediaTypeForPath(mediaFile.path, mediaType),
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
