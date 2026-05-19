class CloudinaryImageUrl {
  static const String _uploadMarker = '/upload/';
  static const String _viewerTransformation =
      'f_auto,q_auto:best,c_limit,w_2400';
  static const String _productCardMainTransformation =
      'f_auto,q_auto:eco,c_limit,w_720,h_720';
  static const String _productCardThumbnailTransformation =
      'f_auto,q_auto:eco,c_fill,g_auto,w_220,h_220';
  static const String _chatThumbnailTransformation =
      'c_fill,g_auto,h_560,w_560,f_auto,q_auto:eco';
  static const String _chatMessageTransformation =
      'c_fill,g_auto,h_1400,w_1400,f_auto,q_auto:good';

  static String forViewer(String imageUrl) {
    return _applyTransformation(imageUrl, _viewerTransformation);
  }

  static String forProductCardMain(String imageUrl) {
    return _applyTransformation(imageUrl, _productCardMainTransformation);
  }

  static String forProductCardThumbnail(String imageUrl) {
    return _applyTransformation(imageUrl, _productCardThumbnailTransformation);
  }

  static String forChatMessage(String imageUrl) {
    return _applyTransformation(imageUrl, _chatMessageTransformation);
  }

  static String forChatThumbnail(String imageUrl) {
    return _applyTransformation(imageUrl, _chatThumbnailTransformation);
  }

  static String _applyTransformation(String imageUrl, String transformation) {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty ||
        !normalizedUrl.contains('res.cloudinary.com')) {
      return normalizedUrl;
    }

    final uploadIndex = normalizedUrl.indexOf(_uploadMarker);
    if (uploadIndex < 0) {
      return normalizedUrl;
    }

    final afterUploadIndex = uploadIndex + _uploadMarker.length;
    RegExpMatch? versionMatch;
    for (final match in RegExp(r'/v\d+/').allMatches(normalizedUrl)) {
      if (match.start >= afterUploadIndex) {
        versionMatch = match;
        break;
      }
    }
    if (versionMatch == null) {
      return normalizedUrl;
    }

    final prefix = normalizedUrl.substring(0, afterUploadIndex);
    final suffix = normalizedUrl.substring(versionMatch.start + 1);

    return '$prefix$transformation/$suffix';
  }
}
