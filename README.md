# view360_call

A Flutter SDK for handling audio/video calls with LiveKit and Firebase Cloud Messaging (FCM).

## Features

- **FCM Token Retrieval**: Fetch and cache FCM device tokens.
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

### 2. Initialize View360Call and Subscribe to Incoming Calls

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
        tokenProvider: ({
          required String roomName,
          required String participantName,
        }) async {
          // Fetch token from backend
          return 'token';
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

    // Initialize SDK (retrieves FCM token & registers message listeners)
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
