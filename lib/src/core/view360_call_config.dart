typedef View360TokenProvider =
    Future<String> Function({
      required String roomName,
      required String participantName,
    });

/// Configuration for the View360Call SDK.
class View360CallConfig {
  /// The LiveKit server URL (e.g. `wss://livekit.example.com`).
  final String serverUrl;

  /// Provider function to retrieve LiveKit authentication tokens.
  final View360TokenProvider tokenProvider;

  /// Optional backend API base URL (e.g. `https://api.example.com`).
  ///
  /// If omitted, the SDK derives the HTTP base URL from [serverUrl]
  /// (`wss://` -> `https://`, `ws://` -> `http://`).
  final String? apiBaseUrl;

  /// The user identifier (ID, username, or email) used to register the FCM device token.
  final String? userId;

  /// Optional device identifier sent when registering the FCM token.
  final String? deviceId;

  /// Optional device type override (e.g. 'android', 'ios', 'web').
  /// If not specified, the SDK automatically detects the current platform.
  final String? deviceType;

  const View360CallConfig({
    required this.serverUrl,
    required this.tokenProvider,
    this.apiBaseUrl,
    this.userId,
    this.deviceId,
    this.deviceType,
  });
}
