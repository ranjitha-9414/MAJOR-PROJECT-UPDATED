# RailAid Flutter App (scaffold)

This folder contains a minimal scaffold for the RailAid Flutter application.

Important next steps before running:

- Install Flutter SDK and open this folder as a Flutter project.
- Add a real `assets/images/rail_aid_logo.png` file (a small PNG).
- Configure Firebase for Android/iOS (google-services.json / GoogleService-Info.plist) and add packages as needed.
- Run `flutter pub get` then `flutter run`.

The scaffold includes:
- `lib/main.dart` — app entry with Provider wiring.
- `lib/services/api_service.dart` — platform-aware ApiService stub.
- `lib/models` and `lib/screens` — simple models and UI.
- `test/widget_test.dart` — a minimal widget smoke test.
