import 'package:flutter_test/flutter_test.dart';
import 'package:view360_call/view360_call.dart';

void main() {
  group('View360CallState', () {
    test('should have correct default values', () {
      const state = View360CallState();

      expect(state.status, View360CallStatus.disconnected);
      expect(state.isMuted, false);
      expect(state.isSpeakerOn, false);
      expect(state.roomName, isNull);
      expect(state.error, isNull);
    });

    test('should store connected call information', () {
      const state = View360CallState(
        status: View360CallStatus.connected,
        roomName: 'test-room',
        isMuted: true,
      );

      expect(state.status, View360CallStatus.connected);
      expect(state.roomName, 'test-room');
      expect(state.isMuted, true);
    });
  });
}
