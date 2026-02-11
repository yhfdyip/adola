import 'package:flutter/foundation.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.time,
    required this.message,
    this.detail,
  });

  final DateTime time;
  final String message;
  final String? detail;

  bool get hasDetail => detail?.trim().isNotEmpty == true;
}

class AppLogService {
  AppLogService._();

  static final AppLogService instance = AppLogService._();

  static const int _maxSize = 100;

  final ValueNotifier<List<AppLogEntry>> logListenable = ValueNotifier(
    const <AppLogEntry>[],
  );

  List<AppLogEntry> get logs => logListenable.value;

  void put(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    final detailParts = <String>[];
    if (error != null) {
      detailParts.add(error.toString());
    }
    if (stackTrace != null) {
      detailParts.add(stackTrace.toString());
    }

    final entry = AppLogEntry(
      time: DateTime.now(),
      message: normalizedMessage,
      detail: detailParts.isEmpty ? null : detailParts.join('\n\n'),
    );

    final next = [entry, ...logListenable.value];
    if (next.length > _maxSize) {
      next.removeRange(_maxSize, next.length);
    }
    logListenable.value = List.unmodifiable(next);
  }

  void clear() {
    logListenable.value = const <AppLogEntry>[];
  }
}

