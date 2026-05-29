import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Lightweight performance tracing facade.
///
/// Usage:
///   final trace = AppPerformance.startTrace('fetch_conversations');
///   // ... work ...
///   await trace.stop();
///
///   // For HTTP calls use the convenience wrapper:
///   final data = await AppPerformance.traceAsync('load_chat', () => apiCall());
///
/// All traces are no-ops in debug builds to avoid polluting the dashboard.
class AppPerformance {
  AppPerformance._();

  static final FirebasePerformance _fp = FirebasePerformance.instance;

  // ── Traces ────────────────────────────────────────────────────────────────

  static Trace startTrace(String name) {
    final trace = _fp.newTrace(name);
    if (!kDebugMode) {
      unawaited(trace.start());
    }
    return trace;
  }

  static Future<T> traceAsync<T>(
    String name,
    Future<T> Function() fn,
  ) async {
    if (kDebugMode) {
      return fn();
    }

    final trace = _fp.newTrace(name);
    await trace.start();
    try {
      return await fn();
    } finally {
      await trace.stop();
    }
  }

  // ── HTTP metrics ──────────────────────────────────────────────────────────

  static HttpMetric? startHttpMetric(String url, HttpMethod method) {
    if (kDebugMode) return null;
    final metric = _fp.newHttpMetric(url, method);
    unawaited(metric.start());
    return metric;
  }

  static Future<void> stopHttpMetric(
    HttpMetric? metric, {
    int? responseCode,
    int? requestPayloadSize,
    int? responsePayloadSize,
  }) async {
    if (metric == null) return;
    if (responseCode != null) metric.httpResponseCode = responseCode;
    if (requestPayloadSize != null) {
      metric.requestPayloadSize = requestPayloadSize;
    }
    if (responsePayloadSize != null) {
      metric.responsePayloadSize = responsePayloadSize;
    }
    await metric.stop();
  }
}
