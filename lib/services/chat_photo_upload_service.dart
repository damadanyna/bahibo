import 'dart:async';

import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

enum ChatPhotoUploadState {
  queued,
  uploading,
  waitingForConnection,
  sendingMessage,
  completed,
  failed,
}

class ChatPhotoUploadTarget {
  final String? conversationId;
  final String? productId;
  final String? targetUserId;

  const ChatPhotoUploadTarget({
    this.conversationId,
    this.productId,
    this.targetUserId,
  });

  bool matches({
    String? conversationId,
    String? productId,
    String? targetUserId,
  }) {
    final normalizedConversationId = conversationId?.trim() ?? '';
    final normalizedProductId = productId?.trim() ?? '';
    final normalizedTargetUserId = targetUserId?.trim() ?? '';

    final currentConversationId = this.conversationId?.trim() ?? '';
    final currentProductId = this.productId?.trim() ?? '';
    final currentTargetUserId = this.targetUserId?.trim() ?? '';

    return (currentConversationId.isNotEmpty &&
            currentConversationId == normalizedConversationId) ||
        (currentProductId.isNotEmpty &&
            currentProductId == normalizedProductId) ||
        (currentTargetUserId.isNotEmpty &&
            currentTargetUserId == normalizedTargetUserId);
  }
}

class ChatPhotoUploadTask {
  final String id;
  final ChatPhotoUploadTarget target;
  final String fileName;
  final Uint8List previewBytes;
  final int? width;
  final int? height;
  final String? mediaGroupId;
  final Map<String, dynamic>? replyPayload;
  final DateTime createdAt;
  final int progressPercent;
  final String statusLabel;
  final ChatPhotoUploadState state;
  final String? errorMessage;
  final Map<String, dynamic>? completedConversationData;
  final String? attachmentUrl;
  final String? originalUrl;
  final String? publicId;

  const ChatPhotoUploadTask({
    required this.id,
    required this.target,
    required this.fileName,
    required this.previewBytes,
    required this.width,
    required this.height,
    required this.mediaGroupId,
    required this.replyPayload,
    required this.createdAt,
    required this.progressPercent,
    required this.statusLabel,
    required this.state,
    required this.errorMessage,
    required this.completedConversationData,
    required this.attachmentUrl,
    required this.originalUrl,
    required this.publicId,
  });

  bool get isTerminal =>
      state == ChatPhotoUploadState.completed ||
      state == ChatPhotoUploadState.failed;

  bool get isVisibleInChat => state != ChatPhotoUploadState.completed;

  ChatPhotoUploadTask copyWith({
    int? progressPercent,
    String? statusLabel,
    ChatPhotoUploadState? state,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<String, dynamic>? completedConversationData,
    String? attachmentUrl,
    String? originalUrl,
    String? publicId,
  }) {
    return ChatPhotoUploadTask(
      id: id,
      target: target,
      fileName: fileName,
      previewBytes: previewBytes,
      width: width,
      height: height,
      mediaGroupId: mediaGroupId,
      replyPayload: replyPayload,
      createdAt: createdAt,
      progressPercent: progressPercent ?? this.progressPercent,
      statusLabel: statusLabel ?? this.statusLabel,
      state: state ?? this.state,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      completedConversationData:
          completedConversationData ?? this.completedConversationData,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      publicId: publicId ?? this.publicId,
    );
  }
}

class ChatPhotoUploadService extends ChangeNotifier {
  ChatPhotoUploadService._();

  static final ChatPhotoUploadService instance = ChatPhotoUploadService._();
  static const int _maxConcurrentUploads = 2;

  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final Connectivity _connectivity = Connectivity();
  final List<ChatPhotoUploadTask> _tasks = <ChatPhotoUploadTask>[];
  final Set<String> _processingTaskIds = <String>{};
  final Map<String, Timer> _cleanupTimers = <String, Timer>{};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternetConnection = true;

  List<ChatPhotoUploadTask> get tasks =>
      List<ChatPhotoUploadTask>.unmodifiable(_tasks);

  List<ChatPhotoUploadTask> tasksForTarget({
    String? conversationId,
    String? productId,
    String? targetUserId,
  }) {
    return _tasks
        .where((task) {
          return task.target.matches(
            conversationId: conversationId,
            productId: productId,
            targetUserId: targetUserId,
          );
        })
        .toList(growable: false)
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  }

  Future<String> enqueuePhotoUpload({
    required ChatPhotoUploadTarget target,
    required Uint8List fileBytes,
    required String fileName,
    int? width,
    int? height,
    String? mediaGroupId,
    Map<String, dynamic>? replyPayload,
  }) async {
    _ensureConnectivityMonitoring();
    await _syncConnectivityState();

    final uploadBytes = await _compressPhoto(fileBytes, fileName: fileName);

    final taskId = 'photo-upload-${DateTime.now().microsecondsSinceEpoch}';
    _tasks.add(
      ChatPhotoUploadTask(
        id: taskId,
        target: target,
        fileName: fileName,
        previewBytes: uploadBytes,
        width: width,
        height: height,
        mediaGroupId: mediaGroupId,
        replyPayload: replyPayload == null
            ? null
            : Map<String, dynamic>.from(replyPayload),
        createdAt: DateTime.now(),
        progressPercent: 2,
        statusLabel: _hasInternetConnection
            ? 'Preparation de l\'envoi...'
            : 'En attente de connexion...',
        state: _hasInternetConnection
            ? ChatPhotoUploadState.queued
            : ChatPhotoUploadState.waitingForConnection,
        errorMessage: null,
        completedConversationData: null,
        attachmentUrl: null,
        originalUrl: null,
        publicId: null,
      ),
    );
    notifyListeners();

    unawaited(_processTask(taskId));
    return taskId;
  }

  void removeTask(String taskId) {
    _cleanupTimers.remove(taskId)?.cancel();
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }

  Future<void> retryPendingTasks() async {
    await _syncConnectivityState();
    if (!_hasInternetConnection) {
      return;
    }

    for (final task in List<ChatPhotoUploadTask>.from(_tasks)) {
      if (task.state == ChatPhotoUploadState.waitingForConnection) {
        unawaited(_processTask(task.id));
      }
    }
  }

  void _ensureConnectivityMonitoring() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  Future<void> _syncConnectivityState() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChanged(results);
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_hasInternetConnection == hasConnection) {
      return;
    }

    _hasInternetConnection = hasConnection;
    if (!hasConnection) {
      for (final task in List<ChatPhotoUploadTask>.from(_tasks)) {
        if (!task.isTerminal) {
          _replaceTask(
            task.id,
            task.copyWith(
              state: ChatPhotoUploadState.waitingForConnection,
              statusLabel: task.attachmentUrl == null
                  ? 'Connexion perdue. Reprise automatique...'
                  : 'Connexion perdue. Finalisation en attente...',
            ),
          );
        }
      }
      return;
    }

    unawaited(retryPendingTasks());
  }

  Future<void> _processTask(String taskId) async {
    final initialTask = _findTask(taskId);
    if (initialTask == null || initialTask.isTerminal) {
      return;
    }
    if (_processingTaskIds.contains(taskId)) {
      return;
    }

    if (_processingTaskIds.length >= _maxConcurrentUploads) {
      // Slot will be claimed when an active upload finishes and calls _drainQueuedTasks.
      return;
    }

    if (!_hasInternetConnection) {
      _replaceTask(
        taskId,
        initialTask.copyWith(
          state: ChatPhotoUploadState.waitingForConnection,
          statusLabel: 'En attente de connexion...',
        ),
      );
      return;
    }

    _processingTaskIds.add(taskId);
    try {
      var currentTask = _findTask(taskId);
      if (currentTask == null || currentTask.isTerminal) {
        return;
      }

      if (currentTask.originalUrl == null || currentTask.originalUrl!.isEmpty) {
        currentTask = currentTask.copyWith(
          state: ChatPhotoUploadState.uploading,
          progressPercent: currentTask.progressPercent < 3
              ? 3
              : currentTask.progressPercent,
          statusLabel: 'Televersement de l\'image...',
          clearErrorMessage: true,
        );
        _replaceTask(taskId, currentTask);

        final upload = await _conversationsApiService.uploadPhotoAttachment(
          fileBytes: currentTask.previewBytes,
          fileName: currentTask.fileName,
          onProgress: (progress) {
            final task = _findTask(taskId);
            if (task == null || task.isTerminal) {
              return;
            }

            final mappedPercent = (3 + (progress.clamp(0, 1) * 83)).round();
            _replaceTask(
              taskId,
              task.copyWith(
                state: ChatPhotoUploadState.uploading,
                progressPercent: mappedPercent.clamp(3, 86),
                statusLabel: 'Televersement de l\'image...',
              ),
            );
          },
        );

        final attachmentUrl = upload['attachmentUrl']?.toString().trim() ?? '';
        final originalUrl = upload['originalUrl']?.toString().trim() ?? '';
        final publicId = upload['publicId']?.toString().trim();
        if (attachmentUrl.isEmpty && originalUrl.isEmpty) {
          throw AppApiException('Photo invalide apres upload');
        }

        currentTask = _findTask(taskId);
        if (currentTask == null || currentTask.isTerminal) {
          return;
        }
        currentTask = currentTask.copyWith(
          state: ChatPhotoUploadState.sendingMessage,
          progressPercent: 92,
          statusLabel: 'Injection dans la conversation...',
          attachmentUrl: attachmentUrl,
          originalUrl: originalUrl,
          publicId: publicId,
        );
        _replaceTask(taskId, currentTask);
      } else {
        _replaceTask(
          taskId,
          currentTask.copyWith(
            state: ChatPhotoUploadState.sendingMessage,
            progressPercent: currentTask.progressPercent.clamp(90, 96),
            statusLabel: 'Injection dans la conversation...',
            clearErrorMessage: true,
          ),
        );
      }

      if (!_hasInternetConnection) {
        final task = _findTask(taskId);
        if (task != null && !task.isTerminal) {
          _replaceTask(
            taskId,
            task.copyWith(
              state: ChatPhotoUploadState.waitingForConnection,
              statusLabel: task.attachmentUrl == null
                  ? 'Connexion perdue. Reprise automatique...'
                  : 'Connexion perdue. Finalisation en attente...',
            ),
          );
        }
        return;
      }

      final completedConversation = await _sendPhotoMessage(taskId);
      final task = _findTask(taskId);
      if (task == null) {
        return;
      }

      _replaceTask(
        taskId,
        task.copyWith(
          state: ChatPhotoUploadState.completed,
          progressPercent: 100,
          statusLabel: 'Photo envoyee',
          completedConversationData: completedConversation,
          clearErrorMessage: true,
        ),
      );

      _cleanupTimers.remove(taskId)?.cancel();
      _cleanupTimers[taskId] = Timer(const Duration(milliseconds: 1400), () {
        removeTask(taskId);
      });
    } on AppApiException catch (error) {
      final task = _findTask(taskId);
      if (task == null || task.isTerminal) {
        return;
      }

      if (_shouldWaitForRetry(error)) {
        _replaceTask(
          taskId,
          task.copyWith(
            state: ChatPhotoUploadState.waitingForConnection,
            statusLabel: task.attachmentUrl == null
                ? 'Connexion indisponible. Reprise automatique...'
                : 'En attente de reseau pour finaliser l\'envoi...',
            errorMessage: error.message,
          ),
        );
        return;
      }

      _replaceTask(
        taskId,
        task.copyWith(
          state: ChatPhotoUploadState.failed,
          statusLabel: error.message,
          errorMessage: error.message,
        ),
      );
    } finally {
      _processingTaskIds.remove(taskId);
      _drainQueuedTasks();
    }
  }

  void _drainQueuedTasks() {
    for (final task in List<ChatPhotoUploadTask>.from(_tasks)) {
      if (_processingTaskIds.length >= _maxConcurrentUploads) break;
      if (!task.isTerminal &&
          !_processingTaskIds.contains(task.id) &&
          task.state == ChatPhotoUploadState.queued) {
        unawaited(_processTask(task.id));
      }
    }
  }

  Future<Map<String, dynamic>> _sendPhotoMessage(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      throw AppApiException('Tache d\'upload introuvable');
    }

    final publicUrl = task.originalUrl?.trim().isNotEmpty == true
        ? task.originalUrl!.trim()
        : (task.attachmentUrl?.trim() ?? '');
    if (publicUrl.isEmpty) {
      throw AppApiException('Photo invalide apres upload');
    }

    final mediaPayload = <String, dynamic>{
      'content': 'Photo envoyee',
      'kind': 'IMAGE',
      'mediaType': 'image',
      'publicUrl': publicUrl,
      'previewUrl': task.attachmentUrl,
      'thumbnailUrl': task.attachmentUrl,
      'fileName': task.fileName,
      'mimeType': _guessMimeTypeFromFileName(task.fileName),
      'fileSizeBytes': task.previewBytes.length,
      'mediaGroupId': task.mediaGroupId,
      'width': task.width,
      'height': task.height,
      'storageProvider': 'cloudinary',
      'storageKey': task.publicId,
    };

    if ((task.target.productId?.trim().isNotEmpty ?? false) &&
        (task.target.targetUserId?.trim().isNotEmpty ?? false) == false) {
      return _conversationsApiService.sendProductMediaMessage(
        productId: task.target.productId!.trim(),
        mediaPayload: mediaPayload,
        reply: task.replyPayload,
      );
    }

    if (task.target.targetUserId?.trim().isNotEmpty ?? false) {
      return _conversationsApiService.sendUserMediaMessage(
        targetUserId: task.target.targetUserId!.trim(),
        mediaPayload: mediaPayload,
        reply: task.replyPayload,
      );
    }

    if (task.target.conversationId?.trim().isNotEmpty ?? false) {
      return _conversationsApiService.sendMediaMessage(
        conversationId: task.target.conversationId!.trim(),
        mediaPayload: mediaPayload,
        reply: task.replyPayload,
      );
    }

    throw AppApiException('Conversation indisponible pour envoyer la photo');
  }

  ChatPhotoUploadTask? _findTask(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  void _replaceTask(String taskId, ChatPhotoUploadTask nextTask) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0) {
      return;
    }

    _tasks[taskIndex] = nextTask;
    notifyListeners();
  }

  bool _shouldWaitForRetry(AppApiException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == null ||
        message.contains('impossible de joindre') ||
        message.contains('connexion') ||
        message.contains('reseau') ||
        !_hasInternetConnection;
  }

  Future<Uint8List> _compressPhoto(
    Uint8List bytes, {
    required String fileName,
  }) async {
    try {
      final ext = fileName.toLowerCase().split('.').last;
      final format =
          ext == 'png' ? CompressFormat.png : CompressFormat.jpeg;
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 85,
        format: format,
      );
    } catch (_) {
      return bytes;
    }
  }

  String _guessMimeTypeFromFileName(String fileName) {
    final extension = fileName
        .substring(fileName.lastIndexOf('.') + 1)
        .toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}
