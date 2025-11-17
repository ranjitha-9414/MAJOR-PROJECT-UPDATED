# RailAid (Scaffold)

Scaffold for the RailAid project (Flutter frontend + optional Node.js backend).

Overview
- Flutter app: `flutter_app` — minimal Material 3 + Provider scaffold, ApiService stub, models, splash, home, and one widget test.
- Backend: `backend` — Node/Express API stub with OTP/auth endpoints and Firebase Admin placeholder.

Quick start (Flutter)

1. Open `flutter_app` in VS Code or run from workspace root:

```powershell
cd flutter_app
flutter pub get
flutter run
```

You must configure Firebase for Android/iOS and add the `assets/images/rail_aid_logo.png` image.

Quick start (Backend)

```powershell
cd backend
npm install
npm run dev
```

See `flutter_app/README.md` and `backend/.env.example` for env hints.
