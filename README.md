# Chat App

A real-time one-to-one chat app built with **Flutter** and **Firebase** (Auth + Cloud Firestore).

<!-- Add screenshots or a GIF here, e.g. ![Chat screen](docs/chat.png) -->

## Features

- Email/password registration and login with inline validation and friendly error messages
- Password reset by email
- Real-time messaging backed by Cloud Firestore streams
- Home screen with a conversation list: last message preview, time and **unread badge**
- Timestamps on every message and **day separators** (Today / Yesterday / date)
- Chat list anchored to the newest message, with auto-scroll on send
- Long-press to **delete your own messages**
- Light / dark theme switch
- **Firestore security rules**: users can only read and write chats they belong to

## Tech stack

| Area | Tools |
| --- | --- |
| UI | Flutter (Material), Provider for theme state |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Tests | `flutter_test` (unit + widget tests) |

## How it works

```
lib/
  main.dart                  App entry, Firebase init, theme provider
  models/message.dart        Message model
  services/auth/             AuthService, AuthGate (routes by login state)
  services/chat/             ChatService (send, stream, delete, unread counters)
  pages/                     Login, Register, Home, Chat, Settings
  components/                Reusable widgets (bubble, tile, text field, button)
  utils/                     Validators, chat helpers, dialogs
firestore.rules              Security rules
```

**Data model**

```
Users/{uid}                          { uid, email }
chat_rooms/{uidA_uidB}               { participants, lastMessage, lastSenderID,
                                       lastTimestamp, unreadCount: {uid: n} }
chat_rooms/{roomId}/messages/{id}    { senderID, senderEmail, receiverID,
                                       message, timestamp }
```

The room ID is the two user IDs sorted and joined with `_`, so both users always
resolve to the same room. Sending a message writes the message and updates the room
summary (last message + receiver's unread counter) in a single atomic batch.

## Security

`firestore.rules` restricts access:

- Any signed-in user can read the `Users` list, but only write their own document
- A user can only read or write a chat room if their UID is part of the room ID
- Messages must be sent as yourself, be 1–2000 characters, can't be edited, and
  can only be deleted by their sender

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and JDK 17 or 21 (Android builds).
2. Create a Firebase project, enable **Email/Password** sign-in and create a **Firestore** database.
3. Register the app with Firebase (`flutterfire configure`, or add your own `google-services.json`
   to `android/app/src/`).
4. Deploy the rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
5. Run:
   ```bash
   flutter pub get
   flutter run
   ```

## Tests

```bash
flutter test
```

## Possible improvements

- Image sharing (Firebase Storage)
- Push notifications (Firebase Cloud Messaging)
- Online / last-seen status
- Group chats
