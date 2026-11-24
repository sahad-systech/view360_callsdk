import 'dart:developer';

import 'controllers/view360_call_controller.dart';
import 'core/view360_call_config.dart';
import 'services/fcm_service.dart';

class View360Call {
  late final View360CallController controller;
  final FCMService _fcmService;
  bool _isInitialized = false;

  View360Call({
    required View360CallConfig config,
    FCMService? fcmService,
  }) : _fcmService = fcmService ?? FCMService() {
    controller = View360CallController(config: config);
  }

  String? get fcmToken => _fcmService.fcmToken;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _fcmService.initialize();
    } catch (e, stackTrace) {
      log(
        'View360Call FCM initialization failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }

    _isInitialized = true;
  }

  Future<void> connect({
    required String roomName,
    required String participantName,
  }) {
    return controller.connect(
      roomName: roomName,
      participantName: participantName,
    );
  }

  Future<void> mute() => controller.mute();

  Future<void> unmute() => controller.unmute();

  Future<void> setSpeakerOn(bool enabled) => controller.setSpeakerOn(enabled);

  Future<void> toggleSpeaker() => controller.toggleSpeaker();

  Future<void> disconnect() => controller.disconnect();

  void dispose() {
    _fcmService.dispose();
    controller.dispose();
  }
}
