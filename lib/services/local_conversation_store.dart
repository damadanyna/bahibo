import 'dart:async';
import 'dart:convert';

import 'package:banay/services/session_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

class LocalConversationStore {
  LocalConversationStore._();

  static final LocalConversationStore instance = LocalConversationStore._();
  static const int _maxMessagesPerConversation = 400;
  static const String _databaseFileName = 'banay_chat_cache.db';
  static const String _conversationStoreName = 'conversation_snapshots';
  static const String _messageStoreName = 'conversation_messages';
  static const String _outboxStoreName = 'conversation_outbox';

  final SessionStorage _sessionStorage = SessionStorage();
  final StoreRef<String, Map<String, Object?>> _conversationStore =
      stringMapStoreFactory.store(_conversationStoreName);
  final StoreRef<String, Map<String, Object?>> _messageStore =
      stringMapStoreFactory.store(_messageStoreName);
  final StoreRef<String, Map<String, Object?>> _outboxStore =
      stringMapStoreFactory.store(_outboxStoreName);
  final StreamController<LocalConversationStoreChange> _changesController =
      StreamController<LocalConversationStoreChange>.broadcast();

  Database? _database;
  Future<Database>? _databaseFuture;

  Stream<LocalConversationStoreChange> get changes => _changesController.stream;

  Future<LocalPendingTextMessage> enqueuePendingTextMessage({
    String? conversationId,
    String? productId,
    String? targetUserId,
    required String content,
    Map<String, dynamic>? replyPayload,
    Map<String, dynamic>? productSnapshot,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw ArgumentError.value(content, 'content', 'Message content is empty');
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final now = DateTime.now();
    final pendingMessage = LocalPendingTextMessage(
      id: 'pending-text-${now.microsecondsSinceEpoch}',
      conversationId: _normalizeOptionalValue(conversationId),
      productId: _normalizeOptionalValue(productId),
      targetUserId: _normalizeOptionalValue(targetUserId),
      content: normalizedContent,
      createdAt: now,
      updatedAt: now,
      status: LocalPendingTextMessageStatus.queued,
      replyPayload: _cloneOptionalMap(replyPayload),
      productSnapshot: _cloneOptionalMap(productSnapshot),
    );

    await _outboxStore
        .record(_outboxRecordKey(accountKey, pendingMessage.id))
        .put(
          database,
          _serializePendingTextMessage(accountKey, pendingMessage),
        );

    _emitChange(
      conversationId: pendingMessage.conversationId,
      cacheKeys: _pendingTargetCacheKeys(
        conversationId: pendingMessage.conversationId,
        productId: pendingMessage.productId,
        targetUserId: pendingMessage.targetUserId,
      ),
      includesPendingTextMessages: true,
    );
    return pendingMessage;
  }

  Future<List<LocalPendingTextMessage>> getPendingTextMessages({
    String? conversationId,
    String? productId,
    String? targetUserId,
  }) async {
    final normalizedConversationId = _normalizeOptionalValue(conversationId);
    final normalizedProductId = _normalizeOptionalValue(productId);
    final normalizedTargetUserId = _normalizeOptionalValue(targetUserId);
    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final records = await _outboxStore.find(
      database,
      finder: Finder(
        filter: Filter.equals('accountKey', accountKey),
        sortOrders: [SortOrder('createdAtMs'), SortOrder('id')],
      ),
    );

    return records
        .map((record) => _deserializePendingTextMessage(record.value))
        .where((message) {
          return message.matches(
            conversationId: normalizedConversationId,
            productId: normalizedProductId,
            targetUserId: normalizedTargetUserId,
          );
        })
        .toList(growable: false);
  }

  Future<LocalPendingTextMessage?> getPendingTextMessage(
    String pendingMessageId,
  ) async {
    final normalizedPendingMessageId = pendingMessageId.trim();
    if (normalizedPendingMessageId.isEmpty) {
      return null;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final record = await _outboxStore
        .record(_outboxRecordKey(accountKey, normalizedPendingMessageId))
        .get(database);
    if (record == null) {
      return null;
    }

    return _deserializePendingTextMessage(record);
  }

  Future<void> markPendingTextMessageSending(String pendingMessageId) {
    return _updatePendingTextMessage(
      pendingMessageId,
      status: LocalPendingTextMessageStatus.sending,
      clearErrorMessage: true,
    );
  }

  Future<void> markPendingTextMessageQueued(
    String pendingMessageId, {
    String? errorMessage,
  }) {
    return _updatePendingTextMessage(
      pendingMessageId,
      status: LocalPendingTextMessageStatus.queued,
      errorMessage: errorMessage,
    );
  }

  Future<void> markPendingTextMessageFailed(
    String pendingMessageId, {
    String? errorMessage,
  }) {
    return _updatePendingTextMessage(
      pendingMessageId,
      status: LocalPendingTextMessageStatus.failed,
      errorMessage: errorMessage,
    );
  }

  Future<void> removePendingTextMessage(String pendingMessageId) async {
    final pendingMessage = await getPendingTextMessage(pendingMessageId);
    if (pendingMessage == null) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    await _outboxStore
        .record(_outboxRecordKey(accountKey, pendingMessage.id))
        .delete(database);

    _emitChange(
      conversationId: pendingMessage.conversationId,
      cacheKeys: _pendingTargetCacheKeys(
        conversationId: pendingMessage.conversationId,
        productId: pendingMessage.productId,
        targetUserId: pendingMessage.targetUserId,
      ),
      includesPendingTextMessages: true,
    );
  }

  Future<void> upsertMessage({
    required String conversationId,
    required Map<String, dynamic> message,
    String? fallbackProductId,
    String? fallbackUserId,
  }) async {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) {
      return;
    }

    final messageId = _messageId(message);
    if (messageId.isEmpty) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final normalizedMessage =
        jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    final aliases = await _knownConversationAliases(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
      fallbackProductId: fallbackProductId,
      fallbackUserId: fallbackUserId,
    );

    await _messageStore
        .record(
          _messageRecordKey(accountKey, normalizedConversationId, messageId),
        )
        .put(database, <String, Object?>{
          'accountKey': accountKey,
          'conversationId': normalizedConversationId,
          'messageId': messageId,
          'createdAtMs': _messageCreatedAtMs(normalizedMessage),
          'orderKey': _messageOrderKey(normalizedMessage),
          'payload': jsonEncode(normalizedMessage),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

    await _pruneConversationMessages(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
    );

    _emitChange(conversationId: normalizedConversationId, cacheKeys: aliases);
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final normalizedConversationId = conversationId.trim();
    final normalizedMessageId = messageId.trim();
    if (normalizedConversationId.isEmpty || normalizedMessageId.isEmpty) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    await _messageStore
        .record(
          _messageRecordKey(
            accountKey,
            normalizedConversationId,
            normalizedMessageId,
          ),
        )
        .delete(database);

    final aliases = await _knownConversationAliases(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
    );
    _emitChange(conversationId: normalizedConversationId, cacheKeys: aliases);
  }

  Future<void> deleteMessagesByMediaGroup({
    required String conversationId,
    required String mediaGroupId,
  }) async {
    final normalizedConversationId = conversationId.trim();
    final normalizedMediaGroupId = mediaGroupId.trim();
    if (normalizedConversationId.isEmpty || normalizedMediaGroupId.isEmpty) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final records = await _messageStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('accountKey', accountKey),
          Filter.equals('conversationId', normalizedConversationId),
        ]),
      ),
    );

    for (final record in records) {
      final payload = record.value['payload'] as String?;
      if (payload == null || payload.isEmpty) {
        continue;
      }

      final message = Map<String, dynamic>.from(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      final media = message['media'];
      final currentGroupId = media is Map
          ? (media['mediaGroupId']?.toString().trim() ?? '')
          : '';
      if (currentGroupId != normalizedMediaGroupId) {
        continue;
      }

      await _messageStore.record(record.key).delete(database);
    }

    final aliases = await _knownConversationAliases(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
    );
    _emitChange(conversationId: normalizedConversationId, cacheKeys: aliases);
  }

  Future<void> markMessageRead({
    required String conversationId,
    required String messageId,
    required String readAt,
  }) async {
    final normalizedConversationId = conversationId.trim();
    final normalizedMessageId = messageId.trim();
    final normalizedReadAt = readAt.trim();
    if (normalizedConversationId.isEmpty ||
        normalizedMessageId.isEmpty ||
        normalizedReadAt.isEmpty) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final recordKey = _messageRecordKey(
      accountKey,
      normalizedConversationId,
      normalizedMessageId,
    );
    final record = await _messageStore.record(recordKey).get(database);
    if (record == null) {
      return;
    }

    final payload = record['payload'] as String?;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final message = Map<String, dynamic>.from(
      jsonDecode(payload) as Map<String, dynamic>,
    )..['readAt'] = normalizedReadAt;

    await _messageStore.record(recordKey).put(database, <String, Object?>{
      ...record,
      'payload': jsonEncode(message),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    final aliases = await _knownConversationAliases(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
    );
    _emitChange(conversationId: normalizedConversationId, cacheKeys: aliases);
  }

  Future<void> markMessageDelivered({
    required String conversationId,
    required String messageId,
    required String deliveredAt,
  }) async {
    final normalizedConversationId = conversationId.trim();
    final normalizedMessageId = messageId.trim();
    final normalizedDeliveredAt = deliveredAt.trim();
    if (normalizedConversationId.isEmpty ||
        normalizedMessageId.isEmpty ||
        normalizedDeliveredAt.isEmpty) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final recordKey = _messageRecordKey(
      accountKey,
      normalizedConversationId,
      normalizedMessageId,
    );
    final record = await _messageStore.record(recordKey).get(database);
    if (record == null) {
      return;
    }

    final payload = record['payload'] as String?;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final message = Map<String, dynamic>.from(
      jsonDecode(payload) as Map<String, dynamic>,
    );
    final existingReadAt = message['readAt']?.toString().trim() ?? '';
    if (existingReadAt.isNotEmpty) {
      return;
    }

    final existingDeliveredAt = message['deliveredAt']?.toString().trim() ?? '';
    if (existingDeliveredAt.isNotEmpty) {
      return;
    }

    message['deliveredAt'] = normalizedDeliveredAt;

    await _messageStore.record(recordKey).put(database, <String, Object?>{
      ...record,
      'payload': jsonEncode(message),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    final aliases = await _knownConversationAliases(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
    );
    _emitChange(conversationId: normalizedConversationId, cacheKeys: aliases);
  }

  Future<void> markOutgoingMessagesRead({
    required String conversationId,
    required String readAt,
  }) async {
    final normalizedConversationId = conversationId.trim();
    final normalizedReadAt = readAt.trim();
    if (normalizedConversationId.isEmpty || normalizedReadAt.isEmpty) {
      return;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final records = await _messageStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('accountKey', accountKey),
          Filter.equals('conversationId', normalizedConversationId),
        ]),
      ),
    );

    var hasUpdatedMessage = false;
    for (final record in records) {
      final payload = record.value['payload'] as String?;
      if (payload == null || payload.isEmpty) {
        continue;
      }

      final message = Map<String, dynamic>.from(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      if (message['isMine'] != true) {
        continue;
      }

      final existingReadAt = message['readAt']?.toString().trim() ?? '';
      if (existingReadAt.isNotEmpty) {
        continue;
      }

      message['readAt'] = normalizedReadAt;
      await _messageStore.record(record.key).put(database, <String, Object?>{
        ...record.value,
        'payload': jsonEncode(message),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      hasUpdatedMessage = true;
    }

    if (!hasUpdatedMessage) {
      return;
    }

    final aliases = await _knownConversationAliases(
      database,
      accountKey: accountKey,
      conversationId: normalizedConversationId,
    );
    _emitChange(conversationId: normalizedConversationId, cacheKeys: aliases);
  }

  Future<void> saveConversationSnapshot(
    Map<String, dynamic> conversation, {
    String? fallbackId,
    String? fallbackProductId,
    String? fallbackUserId,
  }) async {
    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedConversation =
        jsonDecode(jsonEncode(conversation)) as Map<String, dynamic>;
    final conversationId =
        normalizedConversation['id']?.toString().trim() ??
        fallbackId?.trim() ??
        '';
    if (conversationId.isEmpty) {
      return;
    }

    final aliases = _conversationAliases(
      normalizedConversation,
      fallbackId: fallbackId,
      fallbackProductId: fallbackProductId,
      fallbackUserId: fallbackUserId,
    );
    final basePayload = Map<String, dynamic>.from(normalizedConversation)
      ..['messages'] = const <dynamic>[];

    await database.transaction((transaction) async {
      for (final alias in aliases) {
        await _conversationStore
            .record(_conversationRecordKey(accountKey, alias))
            .put(transaction, <String, Object?>{
              'accountKey': accountKey,
              'cacheKey': alias,
              'conversationId': conversationId,
              'payload': jsonEncode(basePayload),
              'updatedAt': timestamp,
            });
      }

      final rawMessages =
          (normalizedConversation['messages'] as List?) ?? const <dynamic>[];
      for (final rawMessage in rawMessages.whereType<Map>()) {
        final message = Map<String, dynamic>.from(rawMessage);
        final messageId = _messageId(message);
        if (messageId.isEmpty) {
          continue;
        }

        await _messageStore
            .record(_messageRecordKey(accountKey, conversationId, messageId))
            .put(transaction, <String, Object?>{
              'accountKey': accountKey,
              'conversationId': conversationId,
              'messageId': messageId,
              'createdAtMs': _messageCreatedAtMs(message),
              'orderKey': _messageOrderKey(message),
              'payload': jsonEncode(message),
              'updatedAt': timestamp,
            });
      }

      await _pruneConversationMessages(
        transaction,
        accountKey: accountKey,
        conversationId: conversationId,
      );
    });

    _changesController.add(
      LocalConversationStoreChange(
        conversationId: conversationId,
        cacheKeys: aliases,
      ),
    );
  }

  Future<Map<String, dynamic>?> getConversationById(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) {
    return _getConversationByCacheKey(
      _conversationCacheKeyById(conversationId),
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Future<Map<String, dynamic>?> getConversationForUser(
    String targetUserId, {
    int? limit,
    String? beforeMessageId,
  }) {
    return _getConversationByCacheKey(
      _conversationCacheKeyByUser(targetUserId),
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Future<Map<String, dynamic>?> getConversationForProduct(
    String productId, {
    int? limit,
    String? beforeMessageId,
  }) {
    return _getConversationByCacheKey(
      _conversationCacheKeyByProduct(productId),
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
  }

  Future<Map<String, dynamic>?> _getConversationByCacheKey(
    String cacheKey, {
    int? limit,
    String? beforeMessageId,
  }) async {
    final normalizedCacheKey = cacheKey.trim();
    if (normalizedCacheKey.isEmpty) {
      return null;
    }

    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    final snapshotRecord = await _conversationStore
        .record(_conversationRecordKey(accountKey, normalizedCacheKey))
        .get(database);
    if (snapshotRecord == null) {
      return null;
    }

    final payload = snapshotRecord['payload'] as String?;
    final conversationId = snapshotRecord['conversationId']?.toString().trim();
    if (payload == null ||
        payload.isEmpty ||
        conversationId == null ||
        conversationId.isEmpty) {
      return null;
    }

    final baseData = Map<String, dynamic>.from(
      jsonDecode(payload) as Map<String, dynamic>,
    );
    final messages = await _loadConversationMessages(
      database,
      accountKey: accountKey,
      conversationId: conversationId,
      limit: limit,
      beforeMessageId: beforeMessageId,
    );
    baseData['messages'] = messages.items;
    baseData['pagination'] = <String, dynamic>{
      'limit': limit,
      'hasOlderMessages': messages.hasOlderMessages,
      'oldestLoadedMessageId': messages.oldestLoadedMessageId,
    };
    return baseData;
  }

  Future<_LocalMessagePage> _loadConversationMessages(
    Database database, {
    required String accountKey,
    required String conversationId,
    int? limit,
    String? beforeMessageId,
  }) async {
    final normalizedBeforeMessageId = beforeMessageId?.trim() ?? '';
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('accountKey', accountKey),
        Filter.equals('conversationId', conversationId),
      ]),
      sortOrders: [SortOrder('orderKey', false)],
    );
    final records = await _messageStore.find(database, finder: finder);
    if (records.isEmpty) {
      return const _LocalMessagePage(items: <Map<String, dynamic>>[]);
    }

    var startIndex = 0;
    if (normalizedBeforeMessageId.isNotEmpty) {
      final beforeIndex = records.indexWhere(
        (record) =>
            record.value['messageId']?.toString() == normalizedBeforeMessageId,
      );
      if (beforeIndex < 0) {
        return const _LocalMessagePage(items: <Map<String, dynamic>>[]);
      }
      startIndex = beforeIndex + 1;
    }

    final pageRecords = limit == null
        ? records.skip(startIndex).toList(growable: false)
        : records.skip(startIndex).take(limit).toList(growable: false);
    final items = pageRecords
        .map((record) => jsonDecode(record.value['payload']! as String))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    final oldestLoadedMessageId = items.isEmpty
        ? null
        : items.first['id']?.toString();

    return _LocalMessagePage(
      items: items,
      hasOlderMessages: startIndex + pageRecords.length < records.length,
      oldestLoadedMessageId: oldestLoadedMessageId,
    );
  }

  Future<void> _pruneConversationMessages(
    DatabaseClient database, {
    required String accountKey,
    required String conversationId,
  }) async {
    final records = await _messageStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('accountKey', accountKey),
          Filter.equals('conversationId', conversationId),
        ]),
        sortOrders: [SortOrder('orderKey', false)],
      ),
    );
    if (records.length <= _maxMessagesPerConversation) {
      return;
    }

    final recordsToDelete = records.skip(_maxMessagesPerConversation);
    for (final record in recordsToDelete) {
      await _messageStore.record(record.key).delete(database);
    }
  }

  Future<Database> _openDatabase() {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return Future.value(existingDatabase);
    }

    final inFlight = _databaseFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _createDatabase();
    _databaseFuture = future;
    return future;
  }

  Future<Database> _createDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(directory.path, _databaseFileName);
    final database = await databaseFactoryIo.openDatabase(databasePath);
    _database = database;
    _databaseFuture = null;
    return database;
  }

  Future<void> _updatePendingTextMessage(
    String pendingMessageId, {
    required LocalPendingTextMessageStatus status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) async {
    final pendingMessage = await getPendingTextMessage(pendingMessageId);
    if (pendingMessage == null) {
      return;
    }

    final nextPendingMessage = pendingMessage.copyWith(
      status: status,
      updatedAt: DateTime.now(),
      errorMessage: clearErrorMessage ? '' : errorMessage,
      clearErrorMessage: clearErrorMessage,
    );
    final database = await _openDatabase();
    final accountKey = await _currentAccountKey();
    await _outboxStore
        .record(_outboxRecordKey(accountKey, nextPendingMessage.id))
        .put(
          database,
          _serializePendingTextMessage(accountKey, nextPendingMessage),
        );

    _emitChange(
      conversationId: nextPendingMessage.conversationId,
      cacheKeys: _pendingTargetCacheKeys(
        conversationId: nextPendingMessage.conversationId,
        productId: nextPendingMessage.productId,
        targetUserId: nextPendingMessage.targetUserId,
      ),
      includesPendingTextMessages: true,
    );
  }

  Future<String> _currentAccountKey() async {
    final phone = await _sessionStorage.getPhoneE164();
    final normalizedPhone = phone?.trim() ?? '';
    return normalizedPhone.isEmpty ? 'anonymous' : normalizedPhone;
  }

  Future<List<String>> _knownConversationAliases(
    Database database, {
    required String accountKey,
    required String conversationId,
    String? fallbackProductId,
    String? fallbackUserId,
  }) async {
    final aliases = <String>{_conversationCacheKeyById(conversationId)};
    final records = await _conversationStore.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('accountKey', accountKey),
          Filter.equals('conversationId', conversationId),
        ]),
      ),
    );

    for (final record in records) {
      final cacheKey = record.value['cacheKey']?.toString().trim() ?? '';
      if (cacheKey.isNotEmpty) {
        aliases.add(cacheKey);
      }
    }

    final normalizedFallbackProductId = _normalizeOptionalValue(
      fallbackProductId,
    );
    if (normalizedFallbackProductId != null) {
      aliases.add(_conversationCacheKeyByProduct(normalizedFallbackProductId));
    }
    final normalizedFallbackUserId = _normalizeOptionalValue(fallbackUserId);
    if (normalizedFallbackUserId != null) {
      aliases.add(_conversationCacheKeyByUser(normalizedFallbackUserId));
    }

    return aliases.toList(growable: false);
  }

  List<String> _pendingTargetCacheKeys({
    String? conversationId,
    String? productId,
    String? targetUserId,
  }) {
    final cacheKeys = <String>{};
    final normalizedConversationId = _normalizeOptionalValue(conversationId);
    if (normalizedConversationId != null) {
      cacheKeys.add(_conversationCacheKeyById(normalizedConversationId));
    }
    final normalizedProductId = _normalizeOptionalValue(productId);
    if (normalizedProductId != null) {
      cacheKeys.add(_conversationCacheKeyByProduct(normalizedProductId));
    }
    final normalizedTargetUserId = _normalizeOptionalValue(targetUserId);
    if (normalizedTargetUserId != null) {
      cacheKeys.add(_conversationCacheKeyByUser(normalizedTargetUserId));
    }
    return cacheKeys.toList(growable: false);
  }

  Map<String, Object?> _serializePendingTextMessage(
    String accountKey,
    LocalPendingTextMessage message,
  ) {
    return <String, Object?>{
      'accountKey': accountKey,
      'id': message.id,
      'conversationId': message.conversationId,
      'productId': message.productId,
      'targetUserId': message.targetUserId,
      'content': message.content,
      'createdAtMs': message.createdAt.millisecondsSinceEpoch,
      'updatedAtMs': message.updatedAt.millisecondsSinceEpoch,
      'status': message.status.name,
      'errorMessage': message.errorMessage,
      'replyPayload': message.replyPayload == null
          ? null
          : jsonEncode(message.replyPayload),
      'productSnapshot': message.productSnapshot == null
          ? null
          : jsonEncode(message.productSnapshot),
    };
  }

  LocalPendingTextMessage _deserializePendingTextMessage(
    Map<String, Object?> record,
  ) {
    final statusName = record['status']?.toString().trim() ?? '';
    final status = LocalPendingTextMessageStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => LocalPendingTextMessageStatus.queued,
    );
    final createdAtMs = (record['createdAtMs'] as num?)?.toInt() ?? 0;
    final updatedAtMs = (record['updatedAtMs'] as num?)?.toInt() ?? createdAtMs;
    return LocalPendingTextMessage(
      id: record['id']?.toString() ?? '',
      conversationId: _normalizeOptionalValue(
        record['conversationId']?.toString(),
      ),
      productId: _normalizeOptionalValue(record['productId']?.toString()),
      targetUserId: _normalizeOptionalValue(record['targetUserId']?.toString()),
      content: record['content']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      status: status,
      errorMessage: _normalizeOptionalValue(record['errorMessage']?.toString()),
      replyPayload: _decodeOptionalMap(record['replyPayload'] as String?),
      productSnapshot: _decodeOptionalMap(record['productSnapshot'] as String?),
    );
  }

  Map<String, dynamic>? _cloneOptionalMap(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic>? _decodeOptionalMap(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(
      jsonDecode(normalizedValue) as Map<String, dynamic>,
    );
  }

  String _outboxRecordKey(String accountKey, String pendingMessageId) {
    return '$accountKey|$pendingMessageId';
  }

  String? _normalizeOptionalValue(String? value) {
    final normalizedValue = value?.trim() ?? '';
    return normalizedValue.isEmpty ? null : normalizedValue;
  }

  void _emitChange({
    String? conversationId,
    List<String> cacheKeys = const <String>[],
    bool includesPendingTextMessages = false,
  }) {
    _changesController.add(
      LocalConversationStoreChange(
        conversationId: conversationId,
        cacheKeys: cacheKeys,
        includesPendingTextMessages: includesPendingTextMessages,
      ),
    );
  }

  List<String> _conversationAliases(
    Map<String, dynamic> conversation, {
    String? fallbackId,
    String? fallbackProductId,
    String? fallbackUserId,
  }) {
    final aliases = <String>{};
    final conversationId =
        conversation['id']?.toString().trim() ?? fallbackId?.trim() ?? '';
    if (conversationId.isNotEmpty) {
      aliases.add(_conversationCacheKeyById(conversationId));
    }

    final product = conversation['product'];
    final productId = product is Map
        ? product['id']?.toString().trim() ?? fallbackProductId?.trim() ?? ''
        : fallbackProductId?.trim() ?? '';
    if (productId.isNotEmpty) {
      aliases.add(_conversationCacheKeyByProduct(productId));
    }

    final participant = conversation['participant'];
    final userId = participant is Map
        ? participant['id']?.toString().trim() ?? fallbackUserId?.trim() ?? ''
        : fallbackUserId?.trim() ?? '';
    if (userId.isNotEmpty) {
      aliases.add(_conversationCacheKeyByUser(userId));
    }

    return aliases.toList(growable: false);
  }

  String _conversationCacheKeyById(String conversationId) {
    return 'id:${conversationId.trim()}';
  }

  String _conversationCacheKeyByProduct(String productId) {
    return 'product:${productId.trim()}';
  }

  String _conversationCacheKeyByUser(String userId) {
    return 'user:${userId.trim()}';
  }

  String _conversationRecordKey(String accountKey, String cacheKey) {
    return '$accountKey|$cacheKey';
  }

  String _messageRecordKey(
    String accountKey,
    String conversationId,
    String messageId,
  ) {
    return '$accountKey|$conversationId|$messageId';
  }

  String _messageId(Map<String, dynamic> message) {
    final explicitId = message['id']?.toString().trim() ?? '';
    if (explicitId.isNotEmpty) {
      return explicitId;
    }

    final createdAt = message['createdAt']?.toString().trim() ?? '';
    final kind = message['kind']?.toString().trim() ?? 'TEXT';
    final content = message['content']?.toString().trim() ?? '';
    return '$createdAt|$kind|$content';
  }

  int _messageCreatedAtMs(Map<String, dynamic> message) {
    final createdAt = message['createdAt']?.toString();
    return DateTime.tryParse(createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
  }

  String _messageOrderKey(Map<String, dynamic> message) {
    final createdAtMs = _messageCreatedAtMs(
      message,
    ).toString().padLeft(16, '0');
    return '$createdAtMs|${_messageId(message)}';
  }
}

class LocalConversationStoreChange {
  const LocalConversationStoreChange({
    required this.conversationId,
    required this.cacheKeys,
    this.includesPendingTextMessages = false,
  });

  final String? conversationId;
  final List<String> cacheKeys;
  final bool includesPendingTextMessages;
}

enum LocalPendingTextMessageStatus { queued, sending, failed }

class LocalPendingTextMessage {
  const LocalPendingTextMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.conversationId,
    this.productId,
    this.targetUserId,
    this.errorMessage,
    this.replyPayload,
    this.productSnapshot,
  });

  final String id;
  final String? conversationId;
  final String? productId;
  final String? targetUserId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalPendingTextMessageStatus status;
  final String? errorMessage;
  final Map<String, dynamic>? replyPayload;
  final Map<String, dynamic>? productSnapshot;

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

  LocalPendingTextMessage copyWith({
    DateTime? updatedAt,
    LocalPendingTextMessageStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return LocalPendingTextMessage(
      id: id,
      conversationId: conversationId,
      productId: productId,
      targetUserId: targetUserId,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      replyPayload: replyPayload == null
          ? null
          : Map<String, dynamic>.from(replyPayload!),
      productSnapshot: productSnapshot == null
          ? null
          : Map<String, dynamic>.from(productSnapshot!),
    );
  }
}

class _LocalMessagePage {
  const _LocalMessagePage({
    required this.items,
    this.hasOlderMessages = false,
    this.oldestLoadedMessageId,
  });

  final List<Map<String, dynamic>> items;
  final bool hasOlderMessages;
  final String? oldestLoadedMessageId;
}
