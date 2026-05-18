import 'dart:async';
import 'dart:typed_data';

import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/conversations_api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ChatDocumentUploadState {
  queued,
  uploading,
  waitingForConnection,
  sendingMessage,
  completed,
  failed,
}

class ChatDocumentUploadTarget {
  const ChatDocumentUploadTarget({
    this.conversationId,
    this.productId,
    this.targetUserId,
  });

  final String? conversationId;
  final String? productId;
  final String? targetUserId;

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

class ChatDocumentUploadTask {
  const ChatDocumentUploadTask({
    required this.id,
    required this.target,
    required this.fileName,
    required this.fileSizeBytes,
    required this.progress,
    required this.statusText,
    required this.state,
    required this.createdAt,
    this.replyPayload,
    this.mediaGroupId,
    this.messageContent,
    this.attachmentUrl,
    this.publicId,
    this.completedConversationData,
    this.errorMessage,
  });

  final String id;
  final ChatDocumentUploadTarget target;
  final String fileName;
  final int fileSizeBytes;
  final double progress;
  final String statusText;
  final ChatDocumentUploadState state;
  final DateTime createdAt;
  final Map<String, dynamic>? replyPayload;
  final String? mediaGroupId;
  final String? messageContent;
  final String? attachmentUrl;
  final String? publicId;
  final Map<String, dynamic>? completedConversationData;
  final String? errorMessage;

  bool get hasFailed => state == ChatDocumentUploadState.failed;
  bool get isTerminal =>
      state == ChatDocumentUploadState.completed ||
      state == ChatDocumentUploadState.failed;
  bool get isVisibleInChat => state != ChatDocumentUploadState.completed;
  int get percent => (progress * 100).round().clamp(0, 100);

  ChatDocumentUploadTask copyWith({
    double? progress,
    String? statusText,
    ChatDocumentUploadState? state,
    String? attachmentUrl,
    String? publicId,
    Map<String, dynamic>? completedConversationData,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatDocumentUploadTask(
      id: id,
      target: target,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      progress: progress ?? this.progress,
      statusText: statusText ?? this.statusText,
      state: state ?? this.state,
      createdAt: createdAt,
      replyPayload: replyPayload,
      mediaGroupId: mediaGroupId,
      messageContent: messageContent,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      publicId: publicId ?? this.publicId,
      completedConversationData:
          completedConversationData ?? this.completedConversationData,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatDocumentUploadService extends ChangeNotifier {
  ChatDocumentUploadService._();

  static final ChatDocumentUploadService instance =
      ChatDocumentUploadService._();

  final ConversationsApiService _conversationsApiService =
      ConversationsApiService();
  final Connectivity _connectivity = Connectivity();
  final List<ChatDocumentUploadTask> _tasks = <ChatDocumentUploadTask>[];
  final Set<String> _processingTaskIds = <String>{};
  final Map<String, Timer> _cleanupTimers = <String, Timer>{};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternetConnection = true;

  List<ChatDocumentUploadTask> tasksForTarget({
    String? conversationId,
    String? productId,
    String? targetUserId,
  }) {
    return _tasks
        .where(
          (task) => task.target.matches(
            conversationId: conversationId,
            productId: productId,
            targetUserId: targetUserId,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  }

  Future<String> enqueueDocumentUpload({
    required ChatDocumentUploadTarget target,
    required Uint8List fileBytes,
    required String fileName,
    required int fileSizeBytes,
    String? mediaGroupId,
    Map<String, dynamic>? replyPayload,
    String? messageContent,
  }) async {
    _ensureConnectivityMonitoring();
    await _syncConnectivityState();

    final taskId = 'document-upload-${DateTime.now().microsecondsSinceEpoch}';
    _tasks.add(
      ChatDocumentUploadTask(
        id: taskId,
        target: target,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        progress: 0,
        statusText: _hasInternetConnection
            ? 'Preparation du document...'
            : 'En attente de connexion...',
        state: _hasInternetConnection
            ? ChatDocumentUploadState.queued
            : ChatDocumentUploadState.waitingForConnection,
        createdAt: DateTime.now(),
        replyPayload: replyPayload == null
            ? null
            : Map<String, dynamic>.from(replyPayload),
        mediaGroupId: mediaGroupId,
        messageContent: messageContent?.trim(),
      ),
    );
    notifyListeners();

    unawaited(_processTask(taskId, fileBytes));
    return taskId;
  }

  void removeTask(String taskId) {
    _cleanupTimers.remove(taskId)?.cancel();
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
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
      for (final task in List<ChatDocumentUploadTask>.from(_tasks)) {
        if (!task.isTerminal) {
          _replaceTask(
            task.id,
            task.copyWith(
              state: ChatDocumentUploadState.waitingForConnection,
              statusText: task.attachmentUrl == null
                  ? 'Connexion perdue. Reprise automatique...'
                  : 'Connexion perdue. Finalisation en attente...',
            ),
          );
        }
      }
      return;
    }

    for (final task in List<ChatDocumentUploadTask>.from(_tasks)) {
      if (task.state == ChatDocumentUploadState.waitingForConnection) {
        _replaceTask(
          task.id,
          task.copyWith(
            state: ChatDocumentUploadState.failed,
            progress: 1,
            statusText: 'Relancez l\'upload du document.',
          ),
        );
      }
    }
  }

  Future<void> _processTask(String taskId, Uint8List fileBytes) async {
    final initialTask = _findTask(taskId);
    if (initialTask == null || initialTask.isTerminal) {
      return;
    }
    if (_processingTaskIds.contains(taskId)) {
      return;
    }

    if (!_hasInternetConnection) {
      _replaceTask(
        taskId,
        initialTask.copyWith(
          state: ChatDocumentUploadState.waitingForConnection,
          statusText: 'En attente de connexion...',
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

      currentTask = currentTask.copyWith(
        state: ChatDocumentUploadState.uploading,
        progress: 0.02,
        statusText: 'Upload du document en cours...',
        clearErrorMessage: true,
      );
      _replaceTask(taskId, currentTask);

      final upload = await _conversationsApiService.uploadDocumentAttachment(
        fileBytes: fileBytes,
        fileName: currentTask.fileName,
        onProgress: (progress) {
          final task = _findTask(taskId);
          if (task == null || task.isTerminal) {
            return;
          }

          final normalizedProgress = progress.clamp(0, 1).toDouble();
          final isUploadComplete = normalizedProgress >= 1;
          _replaceTask(
            taskId,
            task.copyWith(
              progress: isUploadComplete ? 0.94 : normalizedProgress * 0.94,
              statusText: isUploadComplete
                  ? 'Traitement du document sur le serveur...'
                  : 'Upload du document en cours...',
            ),
          );
        },
      );

      final attachmentUrl = upload['attachmentUrl']?.toString().trim() ?? '';
      if (attachmentUrl.isEmpty) {
        throw AppApiException('Document invalide apres upload');
      }

      currentTask = _findTask(taskId);
      if (currentTask == null || currentTask.isTerminal) {
        return;
      }

      currentTask = currentTask.copyWith(
        state: ChatDocumentUploadState.sendingMessage,
        progress: 0.98,
        statusText: 'Finalisation du document...',
        attachmentUrl: attachmentUrl,
        publicId: upload['publicId']?.toString(),
      );
      _replaceTask(taskId, currentTask);

      final completedConversation = await _sendDocumentMessage(taskId);
      final task = _findTask(taskId);
      if (task == null) {
        return;
      }

      _replaceTask(
        taskId,
        task.copyWith(
          state: ChatDocumentUploadState.completed,
          progress: 1,
          statusText: 'Document importe avec succes.',
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

      _replaceTask(
        taskId,
        task.copyWith(
          state: ChatDocumentUploadState.failed,
          progress: 1,
          statusText: error.message,
          errorMessage: error.message,
        ),
      );
    } finally {
      _processingTaskIds.remove(taskId);
    }
  }

  Future<Map<String, dynamic>> _sendDocumentMessage(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) {
      throw AppApiException('Tache d\'upload introuvable');
    }

    final attachmentUrl = task.attachmentUrl?.trim() ?? '';
    if (attachmentUrl.isEmpty) {
      throw AppApiException('Document invalide apres upload');
    }

    final mediaPayload = <String, dynamic>{
      'kind': 'DOCUMENT',
      'mediaType': 'document',
      'publicUrl': attachmentUrl,
      'fileName': task.fileName,
      'mimeType': _guessMimeTypeFromFileName(task.fileName),
      'fileSizeBytes': task.fileSizeBytes,
      'mediaGroupId': task.mediaGroupId,
      'storageProvider': 'cloudinary',
      'storageKey': task.publicId,
    };

    final content = (task.messageContent?.trim().isNotEmpty ?? false)
        ? task.messageContent!.trim()
        : 'Document envoye';

    if ((task.target.productId?.trim().isNotEmpty ?? false) &&
        (task.target.targetUserId?.trim().isNotEmpty ?? false) == false) {
      return _conversationsApiService.sendProductMediaMessage(
        productId: task.target.productId!.trim(),
        mediaPayload: {'content': content, ...mediaPayload},
        reply: task.replyPayload,
      );
    }

    if (task.target.targetUserId?.trim().isNotEmpty ?? false) {
      return _conversationsApiService.sendUserMediaMessage(
        targetUserId: task.target.targetUserId!.trim(),
        mediaPayload: {'content': content, ...mediaPayload},
        reply: task.replyPayload,
      );
    }

    if (task.target.conversationId?.trim().isNotEmpty ?? false) {
      return _conversationsApiService.sendMediaMessage(
        conversationId: task.target.conversationId!.trim(),
        mediaPayload: {'content': content, ...mediaPayload},
        reply: task.replyPayload,
      );
    }

    throw AppApiException('Conversation indisponible pour envoyer le document');
  }

  ChatDocumentUploadTask? _findTask(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  void _replaceTask(String taskId, ChatDocumentUploadTask nextTask) {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0) {
      return;
    }

    _tasks[taskIndex] = nextTask;
    notifyListeners();
  }

  String _guessMimeTypeFromFileName(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    final extension = lastDot < 0 || lastDot == fileName.length - 1
        ? ''
        : fileName.substring(lastDot + 1).toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
