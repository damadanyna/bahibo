import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:banay/services/app_api_client.dart';
import 'package:banay/services/catalog_api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProductUploadTaskState {
  queued,
  uploading,
  waitingForConnection,
  failed,
  completed,
}

enum ProductUploadTaskOperation { create, update }

class ProductUploadTask {
  const ProductUploadTask({
    required this.id,
    required this.operation,
    required this.title,
    required this.description,
    required this.priceAmount,
    required this.categoryName,
    required this.imageFilePaths,
    required this.imageOrder,
    required this.currencyCode,
    required this.createdAt,
    required this.state,
    required this.statusText,
    required this.progress,
    this.productId,
    this.isAvailable,
    this.condition,
    this.previewProduct,
    this.resultProduct,
  });

  final String id;
  final ProductUploadTaskOperation operation;
  final String? productId;
  final String title;
  final String description;
  final double priceAmount;
  final String categoryName;
  final List<String> imageFilePaths;
  final List<String> imageOrder;
  final bool? isAvailable;
  final String currencyCode;
  final String? condition;
  final Map<String, dynamic>? previewProduct;
  final Map<String, dynamic>? resultProduct;
  final DateTime createdAt;
  final ProductUploadTaskState state;
  final String statusText;
  final double progress;

  bool get isTerminal => state == ProductUploadTaskState.completed;

  bool get canResume =>
      state == ProductUploadTaskState.failed ||
      state == ProductUploadTaskState.waitingForConnection;

  ProductUploadTask copyWith({
    ProductUploadTaskOperation? operation,
    String? productId,
    String? title,
    String? description,
    double? priceAmount,
    String? categoryName,
    List<String>? imageFilePaths,
    List<String>? imageOrder,
    bool? isAvailable,
    String? currencyCode,
    String? condition,
    Map<String, dynamic>? previewProduct,
    Map<String, dynamic>? resultProduct,
    DateTime? createdAt,
    ProductUploadTaskState? state,
    String? statusText,
    double? progress,
  }) {
    return ProductUploadTask(
      id: id,
      operation: operation ?? this.operation,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      description: description ?? this.description,
      priceAmount: priceAmount ?? this.priceAmount,
      categoryName: categoryName ?? this.categoryName,
      imageFilePaths: imageFilePaths ?? this.imageFilePaths,
      imageOrder: imageOrder ?? this.imageOrder,
      isAvailable: isAvailable ?? this.isAvailable,
      currencyCode: currencyCode ?? this.currencyCode,
      condition: condition ?? this.condition,
      previewProduct: previewProduct ?? this.previewProduct,
      resultProduct: resultProduct ?? this.resultProduct,
      createdAt: createdAt ?? this.createdAt,
      state: state ?? this.state,
      statusText: statusText ?? this.statusText,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation.name,
      'productId': productId,
      'title': title,
      'description': description,
      'priceAmount': priceAmount,
      'categoryName': categoryName,
      'imageFilePaths': imageFilePaths,
      'imageOrder': imageOrder,
      'isAvailable': isAvailable,
      'currencyCode': currencyCode,
      'condition': condition,
      'previewProduct': previewProduct,
      'resultProduct': resultProduct,
      'createdAt': createdAt.toIso8601String(),
      'state': state.name,
      'statusText': statusText,
      'progress': progress,
    };
  }

  static ProductUploadTask fromJson(Map<String, dynamic> json) {
    final rawState = json['state']?.toString() ?? '';
    final parsedState = ProductUploadTaskState.values.firstWhere(
      (candidate) => candidate.name == rawState,
      orElse: () => ProductUploadTaskState.queued,
    );

    final state = parsedState == ProductUploadTaskState.uploading
        ? ProductUploadTaskState.queued
        : parsedState;

    return ProductUploadTask(
      id: json['id']?.toString() ?? '',
      operation: ProductUploadTaskOperation.values.firstWhere(
        (candidate) => candidate.name == json['operation']?.toString(),
        orElse: () => ProductUploadTaskOperation.create,
      ),
      productId: json['productId']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceAmount: (json['priceAmount'] as num?)?.toDouble() ?? 0,
      categoryName: json['categoryName']?.toString() ?? '',
      imageFilePaths:
          (json['imageFilePaths'] as List?)
              ?.map((entry) => entry.toString())
              .toList(growable: false) ??
          const <String>[],
      imageOrder:
          (json['imageOrder'] as List?)
              ?.map((entry) => entry.toString())
              .toList(growable: false) ??
          const <String>[],
      isAvailable: json['isAvailable'] as bool?,
      currencyCode: json['currencyCode']?.toString() ?? 'MGA',
      condition: json['condition']?.toString(),
      previewProduct: json['previewProduct'] is Map
          ? Map<String, dynamic>.from(json['previewProduct'] as Map)
          : null,
      resultProduct: json['resultProduct'] is Map
          ? Map<String, dynamic>.from(json['resultProduct'] as Map)
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      state: state,
      statusText: json['statusText']?.toString() ?? '',
      progress: ((json['progress'] as num?)?.toDouble() ?? 0.08).clamp(
        0.0,
        1.0,
      ),
    );
  }
}

class ProductUploadQueueService extends ChangeNotifier {
  ProductUploadQueueService._();

  static final ProductUploadQueueService instance =
      ProductUploadQueueService._();

  static const String _storageKey = 'BANAY.pending_product_uploads';

  final CatalogApiService _catalogApiService = CatalogApiService();
  final Connectivity _connectivity = Connectivity();
  final List<ProductUploadTask> _tasks = <ProductUploadTask>[];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasInternetConnection = true;
  bool _isInitialized = false;
  bool _isProcessing = false;

  List<ProductUploadTask> get tasks =>
      List<ProductUploadTask>.unmodifiable(_tasks);

  List<ProductUploadTask> get activeTasks =>
      tasks.where((task) => !task.isTerminal).toList(growable: false)
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

  List<ProductUploadTask> get completedTasks => tasks
      .where((task) => task.state == ProductUploadTaskState.completed)
      .toList(growable: false);

  bool get hasPendingTasks => activeTasks.isNotEmpty;

  bool get hasResumableTasks => tasks.any((task) => task.canResume);

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;
    await _restoreTasks();
    _ensureConnectivityMonitoring();
    await _syncConnectivityState();
    if (_hasInternetConnection) {
      unawaited(_drainQueue());
    }
  }

  Future<String> enqueueCreate({
    required String title,
    required String description,
    required num priceAmount,
    required String categoryName,
    required List<String> imageFilePaths,
    required List<String> imageOrder,
    required Map<String, dynamic> previewProduct,
    String currencyCode = 'MGA',
    String? condition,
  }) async {
    await initialize();
    return _enqueueTask(
      ProductUploadTask(
        id: 'product-upload-${DateTime.now().microsecondsSinceEpoch}',
        operation: ProductUploadTaskOperation.create,
        title: title,
        description: description,
        priceAmount: priceAmount.toDouble(),
        categoryName: categoryName,
        imageFilePaths: List<String>.from(imageFilePaths),
        imageOrder: List<String>.from(imageOrder),
        currencyCode: currencyCode,
        condition: condition,
        previewProduct: Map<String, dynamic>.from(previewProduct),
        createdAt: DateTime.now(),
        state: _hasInternetConnection
            ? ProductUploadTaskState.queued
            : ProductUploadTaskState.waitingForConnection,
        statusText: _hasInternetConnection
            ? 'Synchronisation en attente...'
            : 'Pending: en attente de connexion...',
        progress: _hasInternetConnection ? 0.12 : 0.08,
      ),
    );
  }

  Future<String> enqueueUpdate({
    required String productId,
    required String title,
    required String description,
    required num priceAmount,
    required String categoryName,
    required List<String> imageFilePaths,
    required List<String> imageOrder,
    required Map<String, dynamic> previewProduct,
    bool? isAvailable,
    String currencyCode = 'MGA',
    String? condition,
  }) async {
    await initialize();
    return _enqueueTask(
      ProductUploadTask(
        id: 'product-upload-${DateTime.now().microsecondsSinceEpoch}',
        operation: ProductUploadTaskOperation.update,
        productId: productId,
        title: title,
        description: description,
        priceAmount: priceAmount.toDouble(),
        categoryName: categoryName,
        imageFilePaths: List<String>.from(imageFilePaths),
        imageOrder: List<String>.from(imageOrder),
        isAvailable: isAvailable,
        currencyCode: currencyCode,
        condition: condition,
        previewProduct: Map<String, dynamic>.from(previewProduct),
        createdAt: DateTime.now(),
        state: _hasInternetConnection
            ? ProductUploadTaskState.queued
            : ProductUploadTaskState.waitingForConnection,
        statusText: _hasInternetConnection
            ? 'Synchronisation en attente...'
            : 'Pending: en attente de connexion...',
        progress: _hasInternetConnection ? 0.12 : 0.08,
      ),
    );
  }

  Future<void> resumeAllPending() async {
    await initialize();
    final nextState = _hasInternetConnection
        ? ProductUploadTaskState.queued
        : ProductUploadTaskState.waitingForConnection;

    var hasChanged = false;
    for (var index = 0; index < _tasks.length; index += 1) {
      final task = _tasks[index];
      if (task.isTerminal) {
        continue;
      }

      if (task.state == ProductUploadTaskState.queued &&
          _hasInternetConnection) {
        continue;
      }

      hasChanged = true;
      _tasks[index] = task.copyWith(
        state: nextState,
        statusText: _hasInternetConnection
            ? 'Synchronisation relancee...'
            : 'Pending: en attente de connexion...',
        progress: _hasInternetConnection
            ? (task.progress < 0.12 ? 0.12 : task.progress)
            : (task.progress < 0.08 ? 0.08 : task.progress),
      );
    }

    if (hasChanged) {
      await _persistTasks();
      notifyListeners();
    }

    if (_hasInternetConnection) {
      unawaited(_drainQueue());
    }
  }

  Future<void> retryTask(String taskId) async {
    await initialize();
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return;
    }

    final task = _tasks[index];
    if (task.isTerminal) {
      return;
    }

    _tasks[index] = task.copyWith(
      state: _hasInternetConnection
          ? ProductUploadTaskState.queued
          : ProductUploadTaskState.waitingForConnection,
      statusText: _hasInternetConnection
          ? 'Synchronisation relancee...'
          : 'Pending: en attente de connexion...',
      progress: _hasInternetConnection
          ? (task.progress < 0.12 ? 0.12 : task.progress)
          : (task.progress < 0.08 ? 0.08 : task.progress),
    );
    await _persistTasks();
    notifyListeners();

    if (_hasInternetConnection) {
      unawaited(_drainQueue());
    }
  }

  Future<void> acknowledgeTask(String taskId) async {
    final initialLength = _tasks.length;
    _tasks.removeWhere((task) => task.id == taskId);
    if (_tasks.length == initialLength) {
      return;
    }
    await _persistTasks();
    notifyListeners();
  }

  ProductUploadTask? taskById(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  Future<String> _enqueueTask(ProductUploadTask task) async {
    _tasks.removeWhere((existingTask) => existingTask.id == task.id);
    _tasks.insert(0, task);
    await _persistTasks();
    notifyListeners();
    if (_hasInternetConnection) {
      unawaited(_drainQueue());
    }
    return task.id;
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
      var hasChanged = false;
      for (var index = 0; index < _tasks.length; index += 1) {
        final task = _tasks[index];
        if (task.isTerminal) {
          continue;
        }
        hasChanged = true;
        _tasks[index] = task.copyWith(
          state: ProductUploadTaskState.waitingForConnection,
          statusText: 'Pending: connexion coupee, reprise automatique...',
          progress: task.progress < 0.18 ? 0.18 : task.progress,
        );
      }
      if (hasChanged) {
        unawaited(_persistTasks());
        notifyListeners();
      }
      return;
    }

    var hasChanged = false;
    for (var index = 0; index < _tasks.length; index += 1) {
      final task = _tasks[index];
      if (task.state != ProductUploadTaskState.waitingForConnection) {
        continue;
      }
      hasChanged = true;
      _tasks[index] = task.copyWith(
        state: ProductUploadTaskState.queued,
        statusText: 'Connexion retrouvee. Reprise de la synchronisation...',
        progress: task.progress < 0.22 ? 0.22 : task.progress,
      );
    }

    if (hasChanged) {
      unawaited(_persistTasks());
      notifyListeners();
    }

    unawaited(_drainQueue());
  }

  Future<void> _restoreTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return;
      }

      _tasks
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map(
                (entry) => ProductUploadTask.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .where((task) => task.id.isNotEmpty),
        );
    } catch (_) {
      _tasks.clear();
    }
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> _drainQueue() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    try {
      while (_hasInternetConnection) {
        ProductUploadTask? nextTask;
        for (final task in _tasks) {
          if (task.isTerminal) {
            continue;
          }
          if (task.state == ProductUploadTaskState.queued) {
            nextTask = task;
            break;
          }
        }

        if (nextTask == null) {
          return;
        }

        await _processTask(nextTask);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processTask(ProductUploadTask task) async {
    final imageFiles = <File>[];
    for (final imagePath in task.imageFilePaths) {
      final normalizedPath = imagePath.trim();
      if (normalizedPath.isEmpty) {
        continue;
      }

      final file = File(normalizedPath);
      if (!await file.exists()) {
        _replaceTask(
          task.id,
          task.copyWith(
            state: ProductUploadTaskState.failed,
            statusText:
                'Certaines photos locales sont introuvables. Ouvrez le produit et ajoutez-les de nouveau.',
            progress: task.progress < 0.2 ? 0.2 : task.progress,
          ),
        );
        return;
      }
      imageFiles.add(file);
    }

    _replaceTask(
      task.id,
      task.copyWith(
        state: ProductUploadTaskState.uploading,
        statusText: task.operation == ProductUploadTaskOperation.update
            ? 'Mise a jour en cours en arriere-plan...'
            : 'Publication en cours en arriere-plan...',
        progress: task.progress < 0.14 ? 0.14 : task.progress,
      ),
    );

    try {
      var lastReportedProgress = task.progress;
      var lastReportedImageIndex = 0;
      var lastReportedImagePercent = -1;

      void handleUploadProgress(ProductUploadProgressInfo progressInfo) {
        final uploadProgress = progressInfo.overallProgress;
        final nextProgress = (0.14 + (uploadProgress * 0.8)).clamp(0.14, 0.94);
        final nextImagePercent = (progressInfo.currentImageProgress * 100)
            .floor();
        final shouldSkip =
            (nextProgress - lastReportedProgress).abs() < 0.008 &&
            progressInfo.currentImageIndex == lastReportedImageIndex &&
            nextImagePercent == lastReportedImagePercent;

        if (shouldSkip) {
          return;
        }

        lastReportedProgress = nextProgress;
        lastReportedImageIndex = progressInfo.currentImageIndex;
        lastReportedImagePercent = nextImagePercent;

        _replaceTask(
          task.id,
          (_findTask(task.id) ?? task).copyWith(
            state: ProductUploadTaskState.uploading,
            progress: nextProgress,
            statusText:
                'Image ${progressInfo.currentImageIndex}/${progressInfo.imageCount} • ${nextImagePercent.clamp(0, 100)}%',
          ),
          persist: false,
        );
      }

      final result = task.operation == ProductUploadTaskOperation.update
          ? await _catalogApiService.updateProduct(
              productId: task.productId ?? '',
              title: task.title,
              description: task.description,
              priceAmount: task.priceAmount,
              categoryName: task.categoryName,
              imageFiles: imageFiles,
              imageOrder: task.imageOrder,
              isAvailable: task.isAvailable,
              currencyCode: task.currencyCode,
              onUploadProgress: handleUploadProgress,
            )
          : await _catalogApiService.createProduct(
              title: task.title,
              description: task.description,
              priceAmount: task.priceAmount,
              categoryName: task.categoryName,
              imageFiles: imageFiles,
              imageOrder: task.imageOrder,
              currencyCode: task.currencyCode,
              onUploadProgress: handleUploadProgress,
            );

      _replaceTask(
        task.id,
        task.copyWith(
          state: ProductUploadTaskState.completed,
          statusText: 'Produit synchronise.',
          resultProduct: result,
          progress: 1,
        ),
      );
    } on AppApiException catch (error) {
      final normalizedMessage = error.message.toLowerCase();
      final isConnectionFailure =
          !_hasInternetConnection ||
          normalizedMessage.contains('impossible de joindre le serveur');

      _replaceTask(
        task.id,
        task.copyWith(
          state: isConnectionFailure
              ? ProductUploadTaskState.waitingForConnection
              : ProductUploadTaskState.failed,
          statusText: isConnectionFailure
              ? 'Pending: connexion coupee, reprise automatique...'
              : error.message,
          progress: isConnectionFailure
              ? (task.progress < 0.3 ? 0.3 : task.progress)
              : (task.progress < 0.24 ? 0.24 : task.progress),
        ),
      );
    } catch (_) {
      _replaceTask(
        task.id,
        task.copyWith(
          state: _hasInternetConnection
              ? ProductUploadTaskState.failed
              : ProductUploadTaskState.waitingForConnection,
          statusText: _hasInternetConnection
              ? 'La synchronisation a echoue. Utilisez Reprendre.'
              : 'Pending: connexion coupee, reprise automatique...',
          progress: _hasInternetConnection
              ? (task.progress < 0.24 ? 0.24 : task.progress)
              : (task.progress < 0.3 ? 0.3 : task.progress),
        ),
      );
    }
  }

  ProductUploadTask? _findTask(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  void _replaceTask(
    String taskId,
    ProductUploadTask nextTask, {
    bool persist = true,
  }) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return;
    }

    _tasks[index] = nextTask;
    if (persist) {
      unawaited(_persistTasks());
    }
    notifyListeners();
  }
}
