import 'package:flutter/foundation.dart';

/// Represents a parsed, strongly typed incoming-call event received via FCM.
@immutable
class IncomingCallEvent {
  /// Unique identifier for the call session.
  final String callId;

  /// Identifier of the caller initiating the call.
  final String callerId;

  /// Identifier of the intended call receiver.
  final String receiverId;

  /// Name of the LiveKit / WebRTC room for the call.
  final String roomName;

  /// The timestamp when the call was initiated.
  final DateTime timestamp;

  /// The raw payload received from FCM data.
  final Map<String, dynamic> rawPayload;

  const IncomingCallEvent({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.roomName,
    required this.timestamp,
    this.rawPayload = const {},
  });

  /// Converts this event to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'roomName': roomName,
      'timestamp': timestamp.toIso8601String(),
      'rawPayload': rawPayload,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomingCallEvent &&
          runtimeType == other.runtimeType &&
          callId == other.callId &&
          callerId == other.callerId &&
          receiverId == other.receiverId &&
          roomName == other.roomName &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      callId.hashCode ^
      callerId.hashCode ^
      receiverId.hashCode ^
      roomName.hashCode ^
      timestamp.hashCode;

  @override
  String toString() {
    return 'IncomingCallEvent(callId: $callId, callerId: $callerId, receiverId: $receiverId, roomName: $roomName, timestamp: $timestamp)';
  }
}
