import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  String? _fcmToken;
  StreamSubscription<String>? _registrationSubscription;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    try {
      final completer = Completer<String?>();

      // 1. Subscribe to the onRegistered stream before calling register()
      _registrationSubscription = FirebaseMessaging.instance.onRegistered.listen(
        (token) {
          _fcmToken = token;
          log('View360 FCM Token: $_fcmToken');
          if (!completer.isCompleted) {
            completer.complete(token);
          }
        },
        onError: (e) {
          log('View360 FCM registration stream error: $e');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      // 2. Register this app instance with Firebase Cloud Messaging
      await FirebaseMessaging.instance.register();

      // 3. Await the token with a timeout to avoid blocking initialization indefinitely
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log('View360 FCM registration timed out waiting for initial onRegistered event');
          return null;
        },
      );
    } catch (e) {
      log('View360 FCM token error: $e');
      _fcmToken = null;
    }
  }

  void dispose() {
    _registrationSubscription?.cancel();
    _registrationSubscription = null;
  }
}
