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

    final timestamp = _parseTimestamp(rawTimestamp);

    return IncomingCallEvent(
      callId: callId,
      callerId: callerId,
      receiverId: receiverId,
      roomName: roomName,
      timestamp: timestamp,
      rawPayload: Map<String, dynamic>.unmodifiable(data),
    );
  }

  static DateTime _parseTimestamp(dynamic raw) {
    if (raw is int) {
      final ms = raw < 10000000000 ? raw * 1000 : raw;
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

      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return parsed;
      }

      throw View360CallException('Invalid timestamp format in incoming-call payload: "$raw"');
    }

    throw View360CallException('Unsupported timestamp type: ${raw.runtimeType}');
  }
}
