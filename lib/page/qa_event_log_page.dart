import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:banay/services/app_auth_service.dart';
import 'package:banay/services/app_analytics.dart';
import 'package:banay/services/app_event_log_service.dart';
import 'package:banay/services/notifications_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QaEventLogPage extends StatefulWidget {
  const QaEventLogPage({super.key});

  @override
  State<QaEventLogPage> createState() => _QaEventLogPageState();
}

class _QaEventLogPageState extends State<QaEventLogPage> {
  static const int _maxVisibleEvents = 300;

  final AppAuthService _authService = AppAuthService();
  final NotificationsApiService _notificationsApiService =
      NotificationsApiService();
  final TextEditingController _testerCodeController = TextEditingController();
  final TextEditingController _scenarioIdController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _events = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _serverLogs = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isLoadingServerLogs = false;
  bool _isCopying = false;
  bool _isExporting = false;
  bool _isSendingToBackend = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEvents());
    unawaited(_loadCurrentUser());
    unawaited(_loadServerLogs());
    unawaited(
      AppAnalytics.instance.logUserEvent(
        name: 'qa_log_screen_opened',
        parameters: {'entry_point': 'account_title_long_press'},
        source: 'qa',
      ),
    );
  }

  @override
  void dispose() {
    _testerCodeController.dispose();
    _scenarioIdController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = await _authService.fetchCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = currentUser;
      });
    } catch (_) {
      // Best effort only; the backend will still associate the submission with
      // the authenticated account even if this preview cannot be loaded.
    }
  }

  Future<void> _loadServerLogs() async {
    if (_isLoadingServerLogs) {
      return;
    }
    setState(() {
      _isLoadingServerLogs = true;
    });
    try {
      final serverLogs = await _notificationsApiService.fetchServerLogs();
      if (!mounted) {
        return;
      }
      setState(() {
        _serverLogs = serverLogs;
      });
    } catch (_) {
      // Best effort only; network errors just leave serverLogs empty.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingServerLogs = false;
        });
      }
    }
  }

  Future<void> _loadEvents() async {
    final events = await AppEventLogService.instance.readRecentEvents(
      limit: _maxVisibleEvents,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _buildExportPayload() {
    final testerCode = _testerCodeController.text.trim();
    final scenarioId = _scenarioIdController.text.trim();
    final note = _noteController.text.trim();

    return <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'testerCode': testerCode,
      'scenarioId': scenarioId,
      if (note.isNotEmpty) 'note': note,
      'account': {
        'userId': _currentUser?['id']?.toString().trim(),
        'displayName': _currentUser?['displayName']?.toString().trim(),
        'phoneE164': _currentUser?['phoneE164']?.toString().trim(),
        'role': _currentUser?['role']?.toString().trim(),
      },
      'eventCount': _events.length,
      'events': _events,
      'serverLogCount': _serverLogs.length,
      'serverLogs': _serverLogs,
    };
  }

  String _prettyJsonPayload() {
    return const JsonEncoder.withIndent('  ').convert(_buildExportPayload());
  }

  Future<void> _sendLogsToBackend() async {
    if (_isSendingToBackend || _events.isEmpty) {
      return;
    }

    final testerCode = _testerCodeController.text.trim();
    final scenarioId = _scenarioIdController.text.trim();
    if (testerCode.isEmpty || scenarioId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseigne le code testeur et le scenario teste.'),
        ),
      );
      return;
    }

    setState(() {
      _isSendingToBackend = true;
    });

    try {
      final payload = <String, dynamic>{
        ..._buildExportPayload(),
        'transport': 'notifications_feedback',
        'source': 'qa_hidden_screen',
      };

      await _notificationsApiService.sendQaLogExport(payload);
      await AppAnalytics.instance.logUserEvent(
        name: 'qa_log_sent_to_backend',
        parameters: {
          'event_count': _events.length,
          'tester_code': testerCode,
          'scenario_id': scenarioId,
        },
        source: 'qa',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs QA envoyes au backend avec succes.'),
        ),
      );
    } catch (error) {
      await AppAnalytics.instance.logUserEvent(
        name: 'qa_log_send_to_backend_failed',
        parameters: {
          'tester_code': testerCode,
          'scenario_id': scenarioId,
          'reason': error.toString(),
        },
        source: 'qa',
        status: 'failure',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi backend impossible: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingToBackend = false;
        });
      }
    }
  }

  Future<void> _copyLogs() async {
    if (_isCopying || _events.isEmpty) {
      return;
    }

    setState(() {
      _isCopying = true;
    });

    try {
      final payload = _prettyJsonPayload();
      await Clipboard.setData(ClipboardData(text: payload));
      await AppAnalytics.instance.logUserEvent(
        name: 'qa_log_copied',
        parameters: {'event_count': _events.length},
        source: 'qa',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs QA copies dans le presse-papiers.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCopying = false;
        });
      }
    }
  }

  Future<void> _shareLogs() async {
    if (_isExporting || _events.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File('${directory.path}/banay-qa-logs-$timestamp.json');
      await file.writeAsString(_prettyJsonPayload());
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Export logs QA BANAY',
        text: 'Export des logs QA utilisateur',
      );
      await AppAnalytics.instance.logUserEvent(
        name: 'qa_log_exported',
        parameters: {'event_count': _events.length, 'file_path': file.path},
        source: 'qa',
      );
    } catch (error) {
      await AppAnalytics.instance.logUserEvent(
        name: 'qa_log_export_failed',
        parameters: {'reason': error.toString()},
        source: 'qa',
        status: 'failure',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export impossible: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    if (_isClearing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Vider les logs QA'),
          content: const Text(
            'Supprimer tous les evenements stockes localement sur cet appareil ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Vider'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isClearing = true;
    });

    try {
      await AppEventLogService.instance.clearEvents();
      await AppAnalytics.instance.logUserEvent(
        name: 'qa_log_cleared',
        source: 'qa',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _events = const <Map<String, dynamic>>[];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logs QA effaces.')));
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  String _formatEventSubtitle(Map<String, dynamic> event) {
    final timestamp = event['timestamp']?.toString().trim() ?? '';
    final source = event['source']?.toString().trim() ?? 'ui';
    final status = event['status']?.toString().trim() ?? 'success';
    if (timestamp.isEmpty) {
      return '$source • $status';
    }
    return '$timestamp • $source • $status';
  }

  String _formatParameters(Map<String, dynamic> event) {
    final parameters = event['parameters'];
    if (parameters is Map && parameters.isNotEmpty) {
      return const JsonEncoder.withIndent('  ').convert(parameters);
    }
    return '{}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs QA'),
        actions: [
          IconButton(
            tooltip: 'Rafraichir',
            onPressed: _isLoading
                ? null
                : () {
                    unawaited(_loadEvents());
                    unawaited(_loadServerLogs());
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: theme.colorScheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentUser != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Compte connecte: ${_currentUser?['displayName'] ?? 'Utilisateur'} (${_currentUser?['id'] ?? '-'})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextField(
                  controller: _testerCodeController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Code testeur *',
                    hintText: 'Ex: TESTEUR_01',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scenarioIdController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Scenario teste *',
                    hintText: 'Ex: SEARCH_RESULT_OPEN',
                    prefixIcon: Icon(Icons.rule_folder_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire testeur',
                    hintText: 'Optionnel: bug observe, contexte, appareil...',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.storage_rounded, size: 18),
                      label: Text('${_events.length} evenement(s)'),
                    ),
                    Chip(
                      avatar: _isLoadingServerLogs
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.dns_rounded, size: 18),
                      label: Text('${_serverLogs.length} log(s) serveur'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_isCopying || _events.isEmpty)
                          ? null
                          : _copyLogs,
                      icon: _isCopying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.copy_all_rounded),
                      label: const Text('Copier JSON'),
                    ),
                    FilledButton.icon(
                      onPressed: (_isExporting || _events.isEmpty)
                          ? null
                          : _shareLogs,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share_rounded),
                      label: const Text('Exporter'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: (_isSendingToBackend || _events.isEmpty)
                          ? null
                          : _sendLogsToBackend,
                      icon: _isSendingToBackend
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: const Text('Envoyer au backend'),
                    ),
                    TextButton.icon(
                      onPressed: (_isClearing || _isLoading || _events.isEmpty)
                          ? null
                          : _clearLogs,
                      icon: _isClearing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: const Text('Vider'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun evenement QA stocke pour le moment.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      final eventName =
                          event['name']?.toString().trim().isNotEmpty == true
                          ? event['name'].toString().trim()
                          : 'unknown_event';

                      return Card(
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          title: Text(
                            eventName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_formatEventSubtitle(event)),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectionArea(
                                child: SelectableText(
                                  _formatParameters(event),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
