import 'package:flutter_test/flutter_test.dart';
import 'package:view360_call/src/services/fcm_service.dart';
import 'package:view360_call/view360_call.dart';

class MockFCMService extends FCMService {
  final String? tokenToReturn;
  final bool shouldThrow;
  int initializeCallCount = 0;
  String? _overrideToken;

  MockFCMService({this.tokenToReturn, this.shouldThrow = false});

  @override
  String? get fcmToken => _overrideToken;

  @override
  Future<void> initialize() async {
    initializeCallCount++;
    if (shouldThrow) {
      throw Exception('FCM failed to get token');
    }
    _overrideToken = tokenToReturn;
  }
}

void main() {
  group('View360Call FCM Integration', () {
    final testConfig = View360CallConfig(
      serverUrl: 'wss://test.livekit.cloud',
      tokenProvider: ({required roomName, required participantName}) async => 'test-token',
    );

    test('fcmToken is null before initialization', () {
      final mockFcm = MockFCMService(tokenToReturn: 'mock-fcm-token-123');
      final call = View360Call(config: testConfig, fcmService: mockFcm);

      expect(call.fcmToken, isNull);
      expect(call.isInitialized, isFalse);
    });

    test('fcmToken is fetched when View360Call.initialize() runs and available via call.fcmToken', () async {
      final mockFcm = MockFCMService(tokenToReturn: 'mock-fcm-token-123');
      final call = View360Call(config: testConfig, fcmService: mockFcm);

      await call.initialize();

      expect(mockFcm.initializeCallCount, 1);
      expect(call.isInitialized, isTrue);
      expect(call.fcmToken, 'mock-fcm-token-123');
    });

    test('FCM retrieval failure does not break SDK initialization', () async {
      final mockFcm = MockFCMService(shouldThrow: true);
      final call = View360Call(config: testConfig, fcmService: mockFcm);

      // Should complete without throwing an uncaught exception
      await expectLater(call.initialize(), completes);

      expect(mockFcm.initializeCallCount, 1);
      expect(call.isInitialized, isTrue);
      expect(call.fcmToken, isNull);
    });

    test('repeated initialize() calls do not cause unnecessary token retrieval', () async {
      final mockFcm = MockFCMService(tokenToReturn: 'mock-fcm-token-123');
      final call = View360Call(config: testConfig, fcmService: mockFcm);

      await call.initialize();
      await call.initialize();
      await call.initialize();

      expect(mockFcm.initializeCallCount, 1);
      expect(call.fcmToken, 'mock-fcm-token-123');
    });
  });
}
