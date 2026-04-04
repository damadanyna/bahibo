class CloudinaryImageUrl {
  static const String _uploadMarker = '/upload/';
  static const String _viewerTransformation =
      'f_auto,q_auto:best,c_limit,w_2400';

  static String forViewer(String imageUrl) {
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

    return '$prefix$_viewerTransformation/$suffix';
  }
}
