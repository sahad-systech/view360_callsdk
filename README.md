# view360_call

A Flutter SDK for handling audio/video calls with LiveKit and Firebase Cloud Messaging (FCM).

## Features

- **FCM Token Retrieval & Backend Registration**: Fetch device FCM tokens and automatically register them with your backend API via `POST /api/users/fcm-token`.
- **Incoming Call Handling**: Automatically parse incoming-call events from FCM payloads.
- **Foreground, Background & Terminated States**:
  - Receive incoming calls while the app is in the foreground (`FirebaseMessaging.onMessage`).
  - Handle background FCM messages with the top-level static background handler `View360Call.backgroundMessageHandler`.
  - Handle notification taps when the app is in the background (`FirebaseMessaging.onMessageOpenedApp`).
  - Handle notification taps when the app is launched from a terminated state (`FirebaseMessaging.getInitialMessage`).
- **LiveKit Calling**: Join rooms, toggle microphone/mute, and switch speakerphone.

---

## Host App Integration

### 1. Register Background Handler in `main()`

The host application remains responsible for Firebase initialization. Register `View360Call.backgroundMessageHandler` before `runApp`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:view360_call/view360_call.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register the SDK's top-level static background message handler
  FirebaseMessaging.onBackgroundMessage(
    View360Call.backgroundMessageHandler,
  );

  runApp(const MyApp());
}
```

### 2. Initialize View360Call and Register FCM Token

Provide `apiBaseUrl` (or let it derive from `serverUrl`), `userId`, and optional `deviceId`:

```dart
import 'package:flutter/material.dart';
import 'package:view360_call/view360_call.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final View360Call call;

  @override
  void initState() {
    super.initState();

    call = View360Call(
      config: View360CallConfig(
        serverUrl: 'wss://your-livekit-url.com',
        apiBaseUrl: 'https://your-api-backend.com', // Base URL for /api/users/fcm-token
        userId: 'YOUR_USER_ID_OR_NAME_OR_EMAIL',
        deviceId: 'optional-device-id',
        tokenProvider: ({
          required String roomName,
          required String participantName,
        }) async {
          // Fetch LiveKit room token from backend
          return 'livekit-token';
        },
      ),
    );

    // Subscribe to incoming-call events via callback or stream
    call.onIncomingCall = (IncomingCallEvent event) {
      debugPrint('Incoming Call ID: ${event.callId}');
      debugPrint('Caller ID: ${event.callerId}');
      debugPrint('Receiver ID: ${event.receiverId}');
      debugPrint('Room Name: ${event.roomName}');
      debugPrint('Timestamp: ${event.timestamp}');
    };

    // Initialize SDK (retrieves FCM token, registers to backend, & registers message listeners)
    call.initialize();
  }

  @override
  void dispose() {
    call.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('View360 Call')),
    );
  }
}
```

---

## FCM Token Backend Registration API

Upon retrieving the FCM device token, `FCMService` automatically sends a `POST` request to register the token with your backend:

- **Method**: `POST`
- **URL**: `/api/users/fcm-token`
- **Headers**:
  ```http
  Content-Type: application/json
  ```
- **Request Body**:
  ```json
  {
    "userId": "YOUR_USER_ID_OR_NAME_OR_EMAIL",
    "fcmToken": "PASTE_DEVICE_FCM_TOKEN",
    "deviceType": "android",
    "deviceId": "optional-device-id"
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "message": "FCM token registered successfully"
  }
  ```

You can also manually register tokens using:
```dart
await FCMService.sendTokenToServer(
  fcmToken: token,
  userId: 'user-id',
  baseUrl: 'https://your-api-backend.com',
  deviceId: 'optional-device-id',
);
```

---

## Incoming Call Payload Format

The SDK automatically identifies and parses FCM messages containing `type == 'incoming_call'` in their `data` payload:

```json
{
  "data": {
    "type": "incoming_call",
    "callId": "call-123",
    "callerId": "user-456",
    "receiverId": "user-789",
    "roomName": "room-abc",
    "timestamp": "2026-11-24T18:00:00.000Z"
  }
}
```
*(Supports both camelCase and snake_case field names, and ISO-8601 or millisecond epoch timestamps).*
