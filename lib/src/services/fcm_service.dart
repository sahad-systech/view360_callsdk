import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/view360_call_exception.dart';

/// Service responsible for FCM device token retrieval, caching,
/// and backend server registration via `/api/users/fcm-token`.
class FCMService {
  final FirebaseMessaging? _messaging;
  final http.Client? _httpClient;
  http.Client? _internalClient;

  String? _baseUrl;
  String? _userId;
  String? _deviceId;
  String? _deviceType;
  String? _fcmToken;

  FCMService({
    FirebaseMessaging? messaging,
    http.Client? httpClient,
    String? baseUrl,
    String? userId,
    String? deviceId,
    String? deviceType,
  })  : _messaging = messaging,
        _httpClient = httpClient,
        _baseUrl = baseUrl,
        _userId = userId,
        _deviceId = deviceId,
        _deviceType = deviceType;

  /// The cached FCM token retrieved from [getToken] or [initialize].
  String? get fcmToken => _fcmToken;

  /// The configured API base URL for token registration.
  String? get baseUrl => _baseUrl;

  /// The configured user identifier.
  String? get userId => _userId;

  /// The configured device identifier.
  String? get deviceId => _deviceId;

  /// The configured device type.
  String? get deviceType => _deviceType;

  FirebaseMessaging get _instance => _messaging ?? FirebaseMessaging.instance;

  http.Client get _client {
    if (_httpClient != null) return _httpClient;
    return _internalClient ??= http.Client();
  }

  /// Sets or updates the service's backend registration configuration.
  void setConfig({
    String? baseUrl,
    String? userId,
    String? deviceId,
    String? deviceType,
  }) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (userId != null) _userId = userId;
    if (deviceId != null) _deviceId = deviceId;
    if (deviceType != null) _deviceType = deviceType;
  }

  /// Direct instance method to fetch the FCM device token from Firebase Messaging.
  ///
  /// Updates [fcmToken], optionally registers the token with the backend server if
  /// [userId] and [baseUrl] are provided (or configured), and returns the retrieved token,
  /// or `null` on failure.
  Future<String?> getToken({
    String? vapidKey,
    String? userId,
    String? baseUrl,
    String? deviceId,
    String? deviceType,
    bool registerToServer = true,
  }) async {
    try {
      // ignore: deprecated_member_use
      final token = await _instance.getToken(
        vapidKey: vapidKey,
      );
      _fcmToken = token;
      log('View360 FCM Token: $_fcmToken');

      if (token != null && registerToServer) {
        final targetUserId = userId ?? _userId;
        final targetBaseUrl = baseUrl ?? _baseUrl;

        if (targetUserId != null && targetBaseUrl != null) {
          await registerTokenToServer(
            fcmToken: token,
            userId: targetUserId,
            baseUrl: targetBaseUrl,
            deviceId: deviceId ?? _deviceId,
            deviceType: deviceType ?? _deviceType,
          );
        }
      }

      return token;
    } catch (e) {
      log('View360 FCM token error: $e');
      _fcmToken = null;
      return null;
    }
  }

  /// Registers the FCM device token with the backend server via `POST /api/users/fcm-token`.
  ///
  /// Request format:
  /// ```json
  /// {
  ///   "userId": "YOUR_USER_ID_OR_NAME_OR_EMAIL",
  ///   "fcmToken": "PASTE_DEVICE_FCM_TOKEN",
  ///   "deviceType": "android",
  ///   "deviceId": "optional-device-id"
  /// }
  /// ```
  Future<bool> registerTokenToServer({
    required String fcmToken,
    required String userId,
    String? baseUrl,
    String? deviceType,
    String? deviceId,
    bool throwOnError = false,
  }) async {
    final effectiveBaseUrl = baseUrl ?? _baseUrl;
    if (effectiveBaseUrl == null || effectiveBaseUrl.trim().isEmpty) {
      const msg = 'Cannot register FCM token: baseUrl is null or empty.';
      log('View360 FCMService: $msg');
      if (throwOnError) throw const View360CallException(msg);
      return false;
    }

    try {
      final uri = buildTokenRegistrationUri(effectiveBaseUrl);
      final effectiveDeviceType =
          deviceType ?? _deviceType ?? getDefaultDeviceType();
      final effectiveDeviceId = deviceId ?? _deviceId;

      final body = <String, dynamic>{
        'userId': userId,
        'fcmToken': fcmToken,
        'deviceType': effectiveDeviceType,
        if (effectiveDeviceId != null && effectiveDeviceId.isNotEmpty)
          'deviceId': effectiveDeviceId,
      };

      log('View360 FCM registering token with backend: POST $uri');

      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      log('View360 FCM token registration response: [${response.statusCode}] ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        log('View360 FCM token registered successfully with backend for user: $userId');
        return true;
      } else {
        final errorMsg =
            'Failed to register FCM token. HTTP ${response.statusCode}: ${response.body}';
        log('View360 FCM token registration error: $errorMsg');
        if (throwOnError) {
          throw View360CallException(errorMsg);
        }
        return false;
      }
    } catch (e, stackTrace) {
      log(
        'View360 FCM token registration exception: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (throwOnError) {
        if (e is View360CallException) rethrow;
        throw View360CallException('Error registering FCM token: $e', cause: e);
      }
      return false;
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

  /// Direct static helper to register an FCM device token with the backend server in a single call.
  static Future<bool> sendTokenToServer({
    required String fcmToken,
    required String userId,
    required String baseUrl,
    String? deviceType,
    String? deviceId,
    http.Client? client,
    bool throwOnError = false,
  }) async {
    final service = FCMService(
      httpClient: client,
      baseUrl: baseUrl,
      userId: userId,
      deviceId: deviceId,
      deviceType: deviceType,
    );
    try {
      return await service.registerTokenToServer(
        fcmToken: fcmToken,
        userId: userId,
        baseUrl: baseUrl,
        deviceType: deviceType,
        deviceId: deviceId,
        throwOnError: throwOnError,
      );
    } finally {
      service.dispose();
    }
  }

  /// Initializes the service, caches the token in [fcmToken], and registers
  /// it with the backend server if [userId] and [baseUrl] are provided.
  Future<void> initialize({
    String? vapidKey,
    String? userId,
    String? baseUrl,
    String? deviceId,
    String? deviceType,
    bool registerToServer = true,
  }) async {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (userId != null) _userId = userId;
    if (deviceId != null) _deviceId = deviceId;
    if (deviceType != null) _deviceType = deviceType;

    await getToken(
      vapidKey: vapidKey,
      userId: userId ?? _userId,
      baseUrl: baseUrl ?? _baseUrl,
      deviceId: deviceId ?? _deviceId,
      deviceType: deviceType ?? _deviceType,
      registerToServer: registerToServer,
    );
  }

  /// Disposes resources used by the service.
  void dispose() {
    _fcmToken = null;
    _internalClient?.close();
    _internalClient = null;
  }

  /// Constructs the full URI for the `/api/users/fcm-token` endpoint.
  static Uri buildTokenRegistrationUri(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      return Uri.parse('$base/users/fcm-token');
    }
    return Uri.parse('$base/api/users/fcm-token');
  }

  /// Detects the default device type based on the current Flutter platform.
  static String getDefaultDeviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}

/// Backwards-compatible alias for [FCMService].
typedef View360FCMService = FCMService;
