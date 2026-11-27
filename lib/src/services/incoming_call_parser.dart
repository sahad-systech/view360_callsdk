import '../core/view360_call_exception.dart';
import '../models/incoming_call_event.dart';

/// Dedicated parser for extracting and validating [IncomingCallEvent] payloads from FCM messages.
class IncomingCallParser {
  static const String typeKey = 'type';
  static const String incomingCallType = 'incoming_call';

  /// Determines whether the provided message payload corresponds to an incoming call.
  ///
  /// Returns `true` only if `data['type'] == 'incoming_call'` (or alternative 'notification_type').
  static bool isIncomingCall(Map<String, dynamic>? data) {
    if (data == null) return false;
    final type = data[typeKey] ?? data['notification_type'];
    return type == incomingCallType;
  }

  /// Parses and validates incoming-call payload into a strongly typed [IncomingCallEvent].
  ///
  /// Throws [View360CallException] if the payload is invalid, missing required fields,
  /// or fails validation. Does not silently swallow parsing errors.
  static IncomingCallEvent parse(Map<String, dynamic>? data) {
    if (data == null) {
      throw const View360CallException('Incoming-call payload data is null');
    }

    final type = data[typeKey] ?? data['notification_type'];
    if (type != incomingCallType) {
      throw View360CallException(
        'Invalid notification type "$type" for incoming call. Expected "$incomingCallType"',
      );
    }

    final callId = (data['callId'] ?? data['call_id'])?.toString().trim();
    if (callId == null || callId.isEmpty) {
      throw const View360CallException('Missing or empty "callId" in incoming-call payload');
    }

    final callerId = (data['callerId'] ?? data['caller_id'])?.toString().trim();
    if (callerId == null || callerId.isEmpty) {
      throw const View360CallException('Missing or empty "callerId" in incoming-call payload');
    }

    final receiverId = (data['receiverId'] ?? data['receiver_id'])?.toString().trim();
    if (receiverId == null || receiverId.isEmpty) {
      throw const View360CallException('Missing or empty "receiverId" in incoming-call payload');
    }

    final roomName = (data['roomName'] ?? data['room_name'])?.toString().trim();
    if (roomName == null || roomName.isEmpty) {
      throw const View360CallException('Missing or empty "roomName" in incoming-call payload');
    }

    final rawTimestamp = data['timestamp'];
    if (rawTimestamp == null) {
      throw const View360CallException('Missing "timestamp" in incoming-call payload');
    }

    final callerName = (data['callerName'] ?? data['caller_name'])?.toString().trim();
    final timestamp = _parseTimestamp(rawTimestamp);

    return IncomingCallEvent(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      roomName: roomName,
      timestamp: timestamp,
      callerName: (callerName != null && callerName.isNotEmpty) ? callerName : null,
      rawPayload: Map<String, dynamic>.unmodifiable(data),
    );
  }

  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  static DateTime _parseTimestamp(dynamic raw) {
    if (raw is DateTime) {
      return raw;
    }

    if (raw is num) {
      final intVal = raw.toInt();
      final ms = intVal < 10000000000 ? intVal * 1000 : intVal;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        throw const View360CallException('Empty timestamp in incoming-call payload');
      }

      final intVal = int.tryParse(trimmed);
      if (intVal != null) {
        final ms = intVal < 10000000000 ? intVal * 1000 : intVal;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }

      final doubleVal = double.tryParse(trimmed);
      if (doubleVal != null) {
        final intVal = doubleVal.toInt();
        final ms = intVal < 10000000000 ? intVal * 1000 : intVal;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }

      final parsedIso = DateTime.tryParse(trimmed);
      if (parsedIso != null) {
        return parsedIso;
      }

      if (trimmed.contains('/')) {
        final slashReplaced = DateTime.tryParse(trimmed.replaceAll('/', '-'));
        if (slashReplaced != null) {
          return slashReplaced;
        }
      }

      final parsedFormatted = _parseFormattedDate(trimmed);
      if (parsedFormatted != null) {
        return parsedFormatted;
      }

      throw View360CallException('Invalid timestamp format in incoming-call payload: "$raw"');
    }

    throw View360CallException('Unsupported timestamp type: ${raw.runtimeType}');
  }

  static DateTime? _parseFormattedDate(String input) {
    // 1. Remove parenthesized zone/comment, e.g. "(Coordinated Universal Time)"
    final clean = input.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

    // 2. JavaScript Date.toString() format:
    // e.g. "Thu Nov 26 2026 14:11:24 GMT+0000" or "Nov 26 2026 14:11:24 GMT+0530"
    final jsPattern = RegExp(
      r'^(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*,?\s+)?([A-Za-z]{3,9})\s+(\d{1,2})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s+(.*))?$',
      caseSensitive: false,
    );
    final jsMatch = jsPattern.firstMatch(clean);
    if (jsMatch != null) {
      final monthName = jsMatch.group(1)!.toLowerCase();
      final month = _monthMap[monthName];
      if (month != null) {
        final day = int.tryParse(jsMatch.group(2)!);
        final year = int.tryParse(jsMatch.group(3)!);
        final hour = int.tryParse(jsMatch.group(4)!);
        final minute = int.tryParse(jsMatch.group(5)!);
        final second = int.tryParse(jsMatch.group(6) ?? '0') ?? 0;
        final tzRaw = jsMatch.group(7);

        if (day != null && year != null && hour != null && minute != null) {
          return _buildDateTime(year, month, day, hour, minute, second, tzRaw);
        }
      }
    }

    // 3. RFC 1123 / RFC 2822 format:
    // e.g. "Thu, 26 Nov 2026 14:11:24 GMT" or "26 Nov 2026 14:11:24 +0000"
    final rfcPattern = RegExp(
      r'^(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*,?\s+)?(\d{1,2})[-\s/]+([A-Za-z]{3,9})[-\s/]+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s+(.*))?$',
      caseSensitive: false,
    );
    final rfcMatch = rfcPattern.firstMatch(clean);
    if (rfcMatch != null) {
      final monthName = rfcMatch.group(2)!.toLowerCase();
      final month = _monthMap[monthName];
      if (month != null) {
        final day = int.tryParse(rfcMatch.group(1)!);
        var year = int.tryParse(rfcMatch.group(3)!);
        final hour = int.tryParse(rfcMatch.group(4)!);
        final minute = int.tryParse(rfcMatch.group(5)!);
        final second = int.tryParse(rfcMatch.group(6) ?? '0') ?? 0;
        final tzRaw = rfcMatch.group(7);

        if (year != null && year < 100) {
          year += 2000;
        }

        if (day != null && year != null && hour != null && minute != null) {
          return _buildDateTime(year, month, day, hour, minute, second, tzRaw);
        }
      }
    }

    return null;
  }

  static DateTime? _buildDateTime(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
    String? tzRaw,
  ) {
    final offsetStr = _normalizeTimezoneOffset(tzRaw);
    final isoString = '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}T'
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}'
        '$offsetStr';

    return DateTime.tryParse(isoString);
  }

  static String _normalizeTimezoneOffset(String? tz) {
    if (tz == null || tz.isEmpty) return 'Z';
    final cleanTz = tz.trim();
    final upper = cleanTz.toUpperCase();
    if (upper == 'GMT' || upper == 'UTC' || upper == 'Z') {
      return 'Z';
    }

    final offsetMatch = RegExp(r'([+-])(\d{2}):?(\d{2})').firstMatch(cleanTz);
    if (offsetMatch != null) {
      final sign = offsetMatch.group(1)!;
      final hours = offsetMatch.group(2)!;
      final minutes = offsetMatch.group(3)!;
      if (hours == '00' && minutes == '00') {
        return 'Z';
      }
      return '$sign$hours:$minutes';
    }

    return 'Z';
  }
}
