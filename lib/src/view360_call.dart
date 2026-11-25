import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'controllers/view360_call_controller.dart';
import 'core/view360_call_config.dart';
import 'models/incoming_call_event.dart';
import 'services/fcm_message_handler.dart';
import 'services/fcm_service.dart';
import 'services/incoming_call_parser.dart';

class View360Call {
  late final View360CallController controller;
  final FCMService _fcmService;
  final FCMMessageHandlerService _fcmMessageHandler;
  bool _isInitialized = false;

  void Function(IncomingCallEvent event)? _onIncomingCall;

  /// Optional static callback invoked in the background isolate when an incoming-call arrives.
  ///
  /// Since background isolates do not share memory with the main isolate, this callback
  /// can be registered by the host application in `main()` before `runApp`.
  static Future<void> Function(IncomingCallEvent event)? onBackgroundIncomingCall;

  View360Call({
    required View360CallConfig config,
    FCMService? fcmService,
    FCMMessageHandlerService? fcmMessageHandler,
  })  : _fcmService = fcmService ?? FCMService(),
        _fcmMessageHandler = fcmMessageHandler ?? FCMMessageHandlerService() {
    controller = View360CallController(config: config);
  }

  /// The cached FCM device token, available after [initialize] is called.
  String? get fcmToken => _fcmService.fcmToken;

  /// Whether the SDK instance has completed initialization.
  bool get isInitialized => _isInitialized;

  /// Callback for incoming-call events.
  ///
  /// Example:
  /// ```dart
  /// call.onIncomingCall = (event) {
  ///   print(event.callId);
  ///   print(event.callerId);
  /// };
  /// ```
  void Function(IncomingCallEvent event)? get onIncomingCall => _onIncomingCall;

  set onIncomingCall(void Function(IncomingCallEvent event)? callback) {
    _onIncomingCall = callback;
    _fcmMessageHandler.setCallback(callback);
  }

  /// Stream of incoming-call events.
  Stream<IncomingCallEvent> get incomingCallStream =>
      _fcmMessageHandler.incomingCallStream;

  /// Alias stream of incoming-call events following SDK naming conventions.
  Stream<IncomingCallEvent> get onIncomingCallStream => incomingCallStream;

  /// Initializes the SDK instance.
  ///
  /// - Retrieves the FCM device token.
  /// - Sets up foreground FCM message listeners (`FirebaseMessaging.onMessage`).
  /// - Sets up background notification tap listeners (`FirebaseMessaging.onMessageOpenedApp`).
  /// - Checks for terminated app launch messages (`FirebaseMessaging.getInitialMessage`).
  ///
  /// The host application MUST initialize Firebase before calling this method.
  Future<void> initialize({String? vapidKey}) async {
    if (_isInitialized) return;

    try {
      await _fcmService.initialize(vapidKey: vapidKey);
    } catch (e, stackTrace) {
      log(
        'View360Call FCM token retrieval failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }

    await _fcmMessageHandler.initialize(
      onIncomingCall: _onIncomingCall,
    );

    _isInitialized = true;
  }

  /// Public top-level static background message handler for FlutterFire.
  ///
  /// Register this in the host app's `main()` function before `runApp`:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await Firebase.initializeApp();
  ///   FirebaseMessaging.onBackgroundMessage(View360Call.backgroundMessageHandler);
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// Requirements & Behavior:
  /// - Annotated with `@pragma('vm:entry-point')` for Flutter background execution.
  /// - Initializes Firebase in the background isolate if not already initialized.
  /// - Does NOT access the main SDK instance or any in-memory state.
  /// - Parses and validates incoming-call payloads. Unrelated messages are ignored.
  /// - Keeps background work short and reliable.
  /// - Does NOT perform navigation or display UI directly.
  /// - Does NOT silently swallow parsing errors.
  @pragma('vm:entry-point')
  static Future<void> backgroundMessageHandler(RemoteMessage message) async {
    // 1. Initialize Firebase in the background isolate if necessary.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      log('View360Call backgroundMessageHandler: Firebase initialization: $e');
    }

    // 2. Filter unrelated notifications
    if (!IncomingCallParser.isIncomingCall(message.data)) {
      log('View360Call backgroundMessageHandler: ignoring non-incoming-call message');
      return;
    }

    // 3. Parse and validate incoming-call payload
    try {
      final event = IncomingCallParser.parse(message.data);
      log('View360Call background incoming call received: ${event.callId} for room ${event.roomName}');

      if (onBackgroundIncomingCall != null) {
        await onBackgroundIncomingCall!(event);
      }
    } catch (e, stackTrace) {
      log(
        'View360Call backgroundMessageHandler: Failed to parse incoming call payload: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Do not silently swallow message parsing errors
      rethrow;
    }
  }

  /// Connects to a LiveKit call room.
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
    _fcmMessageHandler.dispose();
    controller.dispose();
  }
}
