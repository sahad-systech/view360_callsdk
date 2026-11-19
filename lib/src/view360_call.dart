import 'controllers/view360_call_controller.dart';
import 'core/view360_call_config.dart';

class View360Call {
  late final View360CallController controller;

  View360Call({required View360CallConfig config}) {
    controller = View360CallController(config: config);
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

  Future<void> disconnect() => controller.disconnect();

  void dispose() {
    controller.dispose();
  }
}
