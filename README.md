# Chat App: Local Business & Customer Messaging

A Flutter + Firebase mobile app that helps small local businesses (salons, barbers, repair shops) take bookings and talk to customers in one place, instead of through scattered WhatsApp messages.

**Live demo:** [your Firebase Hosting URL, or delete this line]

## The problem

Many small businesses in my community take bookings through WhatsApp. Requests get buried in chat, times get double-booked, and customers can't easily see opening hours or whether a business is trustworthy. This app puts the conversation, the available time slots and the reviews in one place.

## Screenshots

| Sign up | Business directory | Business profile | Booking slots | Chat |
|---|---|---|---|---|
| ![](screenshots/register.png) | ![](screenshots/directory.png) | ![](screenshots/business.png) | ![](screenshots/slots.png) | ![](screenshots/chat.png) |

## Features

**Accounts**
- Email/password sign-up and login with validation and friendly error messages
- Choose **Customer** or **Business** at sign-up (enforced by security rules, can't be changed later)
- Password reset by email
- Display names and profile photos from the gallery

**For businesses**
- Business profile: description, hours, phone and address
- **Announcements** shown at the top of the profile (e.g. "Closed Friday")
- Opening and closing times with a live **Open now / Closed** status
- Choose the appointment length (15 to 120 minutes)
- Accept or decline appointment requests

**For customers**
- **Business directory** with search, average rating and open/closed status
- **Book a free time slot**: pick a day, tap an available slot. Taken slots are greyed out and can't be double-booked
- Cancel a pending request, which frees the slot again
- Rate and review a business (1 to 5 stars and a comment), only after chatting with it

**Messaging**
- Real-time one-to-one chat
- Typing indicator, online status and "last seen"
- Unread message counts
- Reply to a message, delete your own messages
- Day separators and timestamps

**Polish**
- Animated splash screen
- Light and dark mode

## Tech stack

| Area | Tools |
|---|---|
| App | Flutter (Dart), Material 3, Provider |
| Auth | Firebase Authentication |
| Database | Cloud Firestore (real-time streams, batched writes) |
| Security | Firestore security rules |
| Testing | `flutter_test` unit and widget tests |

## Architecture

```
lib/
  components/   reusable widgets (chat bubble, booking sheet, star rating...)
  models/       message model
  pages/        screens (login, home, chat, directory, business profile, settings)
  services/     auth, chat, presence, profile, review and slot logic
  utils/        validators, roles, date/time and slot helpers
```

Screens don't talk to Firebase directly. They go through service classes, so logic such as sending messages, reserving slots or saving reviews is separate from the UI.

**Firestore structure**

```
Users/{uid}                            name, email, role, online status
ProfilePhotos/{uid}                    small base64 profile image
BusinessProfiles/{uid}                 details, announcement, hours, slot length
BusinessSlots/{businessId}/booked/{slotId}   one record per taken time slot
BusinessReviews/{businessId}/reviews/{customerId}
chat_rooms/{uidA_uidB}                 last message, unread counts, typing
chat_rooms/{room}/messages/{id}        text or booking messages
```

## How double-booking is prevented

Each taken slot is saved as a document whose ID is its start time (for example `202611201430`). When a customer requests an appointment, the booking message and the slot record are written in **one atomic batch**. If another customer already holds that slot, the write is refused by the security rules and the whole booking fails. Declining or cancelling deletes the slot record, so the time becomes available again.

## Security

Rules in `firestore.rules` enforce that:
- Only the two people in a chat can read or write its messages
- You can only delete your own messages
- A user's account type can't be changed after sign-up
- Only business accounts can edit business profiles, and only customers can send bookings to businesses
- Only the business can accept or decline a booking, and only the customer can cancel it
- A slot can only be reserved once, and only the customer or the business can release it
- Reviews need a rating of 1 to 5, one per customer per business, and only from customers who have chatted with that business

## Run it locally

Requirements: Flutter 3.38+, a Firebase project.

```bash
git clone [your repo url]
cd chat_app
flutter pub get
```

1. Create a Firebase project and enable **Authentication → Email/Password** and **Cloud Firestore**.
2. Add the Android app and put `google-services.json` in `android/app/`.
3. Deploy the rules: `firebase deploy --only firestore:rules --project [your-project-id]`
4. `flutter run`

## Tests

```bash
flutter test
flutter analyze
```

## Design decisions and limitations

- **No custom backend.** Firebase handles auth, data and real-time sync, so I focused on the app and the security rules.
- **Profile photos are small base64 images in Firestore** (resized to 256px) because Firebase Storage needs a paid plan. For production I'd move them to Storage.
- **Reviews are not verified purchases.** Requiring a prior chat is a basic safeguard. A completed booking would be stronger.
- **Average ratings are computed on the client** from the latest 50 reviews. At scale I'd keep aggregates updated with Cloud Functions.
- **Slots use one set of opening hours for every day** and the phone's local time zone. Days off, breaks and multiple time zones are not handled yet.
- **A slot is held as soon as it is requested**, even while the booking is still pending.
- **No push notifications yet.** Users see unread badges inside the app.

## Roadmap

- Push notifications for new messages and booking updates (Firebase Cloud Messaging)
- Days off and break times per business
- Business categories (salon, barber, repair) with filtering
- Image sharing in chat

## Author

[Your name] · [LinkedIn] · [email]
