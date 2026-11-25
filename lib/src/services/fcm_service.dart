import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Service responsible for FCM device token retrieval and caching.
class FCMService {
  final FirebaseMessaging? _messaging;
  String? _fcmToken;

  FCMService({FirebaseMessaging? messaging}) : _messaging = messaging;

  /// The cached FCM token retrieved from [getToken] or [initialize].
  String? get fcmToken => _fcmToken;

  FirebaseMessaging get _instance => _messaging ?? FirebaseMessaging.instance;

  /// Direct instance method to fetch the FCM device token from Firebase Messaging.
  ///
  /// Updates [fcmToken] and returns the retrieved token, or `null` on failure.
  Future<String?> getToken({String? vapidKey}) async {
    try {
      // ignore: deprecated_member_use
      final token = await _instance.getToken(
        vapidKey: vapidKey,
      );
      _fcmToken = token;
      log('View360 FCM Token: $_fcmToken');
      return token;
    } catch (e) {
      log('View360 FCM token error: $e');
      _fcmToken = null;
      return null;
    }
  }

  /// Direct static helper to retrieve the FCM device token in a single call from the host app:
  ///
  /// ```dart
  /// final token = await FCMService.getDeviceToken();
  /// ```
  static Future<String?> getDeviceToken({String? vapidKey}) async {
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: vapidKey,
      );
      log('View360 FCM Token: $token');
      return token;
    } catch (e) {
      log('View360 FCM token error: $e');
      return null;
    }
  }

  /// Initializes the service and caches the token in [fcmToken].
  Future<void> initialize({String? vapidKey}) async {
    await getToken(vapidKey: vapidKey);
  }

  void dispose() {
    _fcmToken = null;
  }
}

/// Backwards-compatible alias for [FCMService].
typedef View360FCMService = FCMService;
