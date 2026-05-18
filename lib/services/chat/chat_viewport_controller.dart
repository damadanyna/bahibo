import 'package:flutter/widgets.dart';

class ChatViewportController extends ChangeNotifier {
  ChatViewportController({
    required ScrollController scrollController,
    this.scrollToLatestThreshold = 220,
    this.scrollRetryCount = 4,
    this.animationDuration = const Duration(milliseconds: 260),
    this.animationCurve = Curves.easeOutCubic,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final double scrollToLatestThreshold;
  final int scrollRetryCount;
  final Duration animationDuration;
  final Curve animationCurve;

  bool _showScrollToLatestButton = false;
  bool _disposed = false;

  bool get showScrollToLatestButton => _showScrollToLatestButton;

  bool get shouldKeepViewportPinnedToBottom {
    if (!_scrollController.hasClients) {
      return true;
    }

    return _scrollController.position.pixels <= scrollToLatestThreshold;
  }

  void handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;
    final shouldShowScrollToLatest = offset > scrollToLatestThreshold;
    if (shouldShowScrollToLatest == _showScrollToLatestButton) {
      return;
    }

    _showScrollToLatestButton = shouldShowScrollToLatest;
    notifyListeners();
  }

  void scheduleScrollToBottom({int? remaining}) {
    final attempts = remaining ?? scrollRetryCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      if (!_scrollController.hasClients) {
        if (attempts > 0) {
          scheduleScrollToBottom(remaining: attempts - 1);
        }
        return;
      }

      jumpToBottom();
      if (attempts > 0) {
        scheduleScrollToBottom(remaining: attempts - 1);
      }
    });
  }

  void scheduleBottomAnchor({required bool shouldStayPinnedToBottom}) {
    if (!shouldStayPinnedToBottom || _disposed) {
      return;
    }

    scheduleScrollToBottom();
  }

  void jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  void animateToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: animationDuration,
      curve: animationCurve,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
