import 'dart:developer';

import 'package:livekit_client/livekit_client.dart';

import '../core/view360_call_exception.dart';

class LiveKitService {
  Room? _room;

  Room? get room => _room;

  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  Future<void> connect({
    required String serverUrl,
    required String token,
  }) async {
    if (_room != null) {
      throw const View360CallException(
        'A LiveKit room is already initialized.',
      );
    }

    final room = Room();
    _room = room;

    try {
      log('[LiveKitService] Connecting to LiveKit room at $serverUrl...');
      await room.connect(serverUrl, token);
      log(
        '[LiveKitService] room.connect() completed successfully. Connection state: ${room.connectionState}',
      );
    } catch (error, stackTrace) {
      log(
        '[LiveKitService] Failure occurred during room.connect(): $error',
        error: error,
        stackTrace: stackTrace,
      );
      log('[LiveKitService] room.connect() stack trace:\n$stackTrace');

      await _safeDisconnect(room);

      throw View360CallException(
        'Failed during room.connect(): $error',
        cause: error,
      );
    }

    try {
      log(
        '[LiveKitService] Initializing microphone (setMicrophoneEnabled(true))...',
      );
      await room.localParticipant?.setMicrophoneEnabled(true);
      log('[LiveKitService] Microphone initialized successfully.');
    } catch (error, stackTrace) {
      log(
        '[LiveKitService] Failure occurred during microphone initialization: $error',
        error: error,
        stackTrace: stackTrace,
      );
      log(
        '[LiveKitService] Microphone initialization stack trace:\n$stackTrace',
      );

      await _safeDisconnect(room);

      throw View360CallException(
        'Failed during microphone initialization: $error',
        cause: error,
      );
    }
  }

  Future<void> mute() async {
    final participant = _room?.localParticipant;

    if (participant == null) {
      throw const View360CallException('Not connected to a LiveKit room.');
    }

    await participant.setMicrophoneEnabled(false);
  }

  Future<void> unmute() async {
    final participant = _room?.localParticipant;

    if (participant == null) {
      throw const View360CallException('Not connected to a LiveKit room.');
    }

    await participant.setMicrophoneEnabled(true);
  }

  Future<void> disconnect() async {
    final room = _room;

    if (room == null) return;

    _room = null;
    await room.disconnect();
  }

  Future<void> _safeDisconnect(Room room) async {
    _room = null;
    try {
      await room.disconnect();
    } catch (disconnectError, disconnectStackTrace) {
      log(
        '[LiveKitService] Error while disconnecting room after failure: $disconnectError',
        error: disconnectError,
        stackTrace: disconnectStackTrace,
      );
    }
  }
}
