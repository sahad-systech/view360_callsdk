import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../core/view360_call_config.dart';
import '../core/view360_call_state.dart';
import '../services/livekit_service.dart';

class View360CallController extends ChangeNotifier {
  final View360CallConfig config;
  final LiveKitService _liveKitService;

  View360CallState _state = const View360CallState();

  View360CallState get state => _state;

  View360CallController({required this.config, LiveKitService? liveKitService})
    : _liveKitService = liveKitService ?? LiveKitService();

  Future<void> connect({
    required String roomName,
    required String participantName,
  }) async {
    if (_state.status == View360CallStatus.connecting ||
        _state.status == View360CallStatus.connected) {
      return;
    }

    _updateState(
      View360CallState(
        status: View360CallStatus.connecting,
        roomName: roomName,
      ),
    );

    try {
      final token = await config.tokenProvider(
        roomName: roomName,
        participantName: participantName,
      );

      log('LiveKit URL: ${config.serverUrl}');
      log('Connecting to room: $roomName');

      await _liveKitService.connect(serverUrl: config.serverUrl, token: token);

      _updateState(
        View360CallState(
          status: View360CallStatus.connected,
          roomName: roomName,
          isSpeakerOn: _liveKitService.isSpeakerOn,
        ),
      );

      log('LiveKit connected successfully');
    } catch (error, stackTrace) {
      log('LiveKit connection failed: $error', stackTrace: stackTrace);

      _updateState(
        View360CallState(
          status: View360CallStatus.failed,
          roomName: roomName,
          error: error.toString(),
        ),
      );

      rethrow;
    }
  }

  Future<void> mute() async {
    await _liveKitService.mute();

    _updateState(
      View360CallState(
        status: _state.status,
        roomName: _state.roomName,
        isMuted: true,
        isSpeakerOn: _state.isSpeakerOn,
      ),
    );
  }

  Future<void> unmute() async {
    await _liveKitService.unmute();

    _updateState(
      View360CallState(
        status: _state.status,
        roomName: _state.roomName,
        isMuted: false,
        isSpeakerOn: _state.isSpeakerOn,
      ),
    );
  }

  Future<void> setSpeakerOn(bool enabled) async {
    await _liveKitService.setSpeakerOn(enabled);

    _updateState(
      View360CallState(
        status: _state.status,
        roomName: _state.roomName,
        isMuted: _state.isMuted,
        isSpeakerOn: enabled,
        error: _state.error,
      ),
    );
  }

  Future<void> toggleSpeaker() async {
    final nextState = !_state.isSpeakerOn;
    await setSpeakerOn(nextState);
  }

  Future<void> disconnect() async {
    if (_state.status == View360CallStatus.disconnected) return;

    _updateState(
      View360CallState(
        status: View360CallStatus.disconnecting,
        roomName: _state.roomName,
      ),
    );

    try {
      await _liveKitService.disconnect();

      _updateState(const View360CallState());
    } catch (error) {
      _updateState(
        View360CallState(
          status: View360CallStatus.failed,
          error: error.toString(),
        ),
      );

      rethrow;
    }
  }

  void _updateState(View360CallState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _liveKitService.disconnect();
    super.dispose();
  }
}
