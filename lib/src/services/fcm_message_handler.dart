import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/incoming_call_event.dart';
import 'incoming_call_parser.dart';

/// Dedicated service responsible for FCM message listening and incoming-call event distribution.
///
/// Handles:
/// - Foreground messages (`FirebaseMessaging.onMessage`)
/// - Background notification taps (`FirebaseMessaging.onMessageOpenedApp`)
/// - Terminated app launch notification taps (`FirebaseMessaging.getInitialMessage`)
/// - Deduplication of initial launch messages and duplicate listener prevention.
class FCMMessageHandlerService {
  final Stream<RemoteMessage>? _customOnMessageStream;
  final Stream<RemoteMessage>? _customOnMessageOpenedAppStream;
  final Future<RemoteMessage?> Function()? _customGetInitialMessage;

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  final StreamController<IncomingCallEvent> _incomingCallController =
      StreamController<IncomingCallEvent>.broadcast();

  final List<IncomingCallEvent> _pendingEvents = [];
  void Function(IncomingCallEvent event)? _onIncomingCallCallback;

  bool _isInitialized = false;
  bool _initialMessageHandled = false;
  String? _handledInitialMessageId;

  FCMMessageHandlerService({
    Stream<RemoteMessage>? onMessageStream,
    Stream<RemoteMessage>? onMessageOpenedAppStream,
    Future<RemoteMessage?> Function()? getInitialMessageFn,
  })  : _customOnMessageStream = onMessageStream,
        _customOnMessageOpenedAppStream = onMessageOpenedAppStream,
        _customGetInitialMessage = getInitialMessageFn;

  /// Whether message listeners have been registered.
  bool get isInitialized => _isInitialized;

  /// Whether the initial message from a terminated state has already been processed.
  bool get initialMessageHandled => _initialMessageHandled;

  /// Broadcast stream of incoming-call events.
  Stream<IncomingCallEvent> get incomingCallStream => _incomingCallController.stream;

  /// Sets or updates the active incoming-call callback.
  ///
  /// Flushes any pending events that arrived before the callback was registered.
  void setCallback(void Function(IncomingCallEvent event)? callback) {
    _onIncomingCallCallback = callback;
    if (callback != null) {
      flushPendingEvents(callback);
    }
  }

  /// Flushes any queued incoming-call events that arrived before callback registration.
  void flushPendingEvents(void Function(IncomingCallEvent event) callback) {
    if (_pendingEvents.isEmpty) return;
    final buffered = List<IncomingCallEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    for (final event in buffered) {
      callback(event);
    }
  }

  /// Initializes message listeners and checks for terminated app launch messages.
  ///
  /// Prevents registering duplicate listeners if called multiple times.
  Future<void> initialize({
    void Function(IncomingCallEvent event)? onIncomingCall,
  }) async {
    if (onIncomingCall != null) {
      _onIncomingCallCallback = onIncomingCall;
    }

    if (_isInitialized) {
      log('View360Call: FCMMessageHandlerService already initialized, skipping duplicate listener registration.');
      return;
    }
    _isInitialized = true;

    // 1. Foreground message listener
    final onMessageStream =
        _customOnMessageStream ?? FirebaseMessaging.onMessage;
    _onMessageSubscription = onMessageStream.listen(
      _handleRemoteMessage,
      onError: (error, stackTrace) {
        log('View360Call: FCM onMessage error: $error', error: error, stackTrace: stackTrace);
      },
    );

    // 2. Background notification tap listener (app was in background)
    final onMessageOpenedAppStream =
        _customOnMessageOpenedAppStream ?? FirebaseMessaging.onMessageOpenedApp;
    _onMessageOpenedAppSubscription = onMessageOpenedAppStream.listen(
      _handleRemoteMessage,
      onError: (error, stackTrace) {
        log('View360Call: FCM onMessageOpenedApp error: $error', error: error, stackTrace: stackTrace);
      },
    );

    // 3. Terminated app launch handling (app opened by tapping notification)
    await _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    if (_initialMessageHandled) return;

    try {
      final getInitial = _customGetInitialMessage ??
          FirebaseMessaging.instance.getInitialMessage;
      final initialMessage = await getInitial();

      if (initialMessage != null) {
        // Prevent processing the exact same initial message multiple times
        final messageId = initialMessage.messageId;
        if (_initialMessageHandled ||
            (messageId != null && messageId == _handledInitialMessageId)) {
          log('View360Call: Initial message already processed ($messageId)');
          return;
        }

        _initialMessageHandled = true;
        _handledInitialMessageId = messageId;
        _handleRemoteMessage(initialMessage);
      }
    } catch (error, stackTrace) {
      log(
        'View360Call: Error checking getInitialMessage: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Processes an incoming [RemoteMessage].
  ///
  /// Validates whether it is an incoming-call notification. Unrelated messages
  /// are ignored. Valid incoming calls are dispatched to callbacks and streams.
  /// If parsing fails on an incoming-call notification, the error is not swallowed.
  void _handleRemoteMessage(RemoteMessage message) {
    final data = message.data;
    if (!IncomingCallParser.isIncomingCall(data)) {
      // Ignore unrelated notifications
      return;
    }

    try {
      final event = IncomingCallParser.parse(data);
      _deliverEvent(event);
    } catch (error, stackTrace) {
      log(
        'View360Call: Failed to parse incoming-call payload: $error',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_incomingCallController.isClosed) {
        _incomingCallController.addError(error, stackTrace);
      }
    }
  }

  void _deliverEvent(IncomingCallEvent event) {
    if (!_incomingCallController.isClosed) {
      _incomingCallController.add(event);
    }

    if (_onIncomingCallCallback != null) {
      _onIncomingCallCallback!(event);
    } else {
      _pendingEvents.add(event);
    }
  }

  /// Disposes message subscriptions and streams.
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = null;
    _incomingCallController.close();
    _pendingEvents.clear();
    _onIncomingCallCallback = null;
    _isInitialized = false;
  }
}
