# EsquiloSpeak mobile

Flutter learner application for the first learning vertical slice.

## Commands

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
```

The Android emulator resolves the local backend through
`http://10.0.2.2:8080`. Override it for another environment:

```powershell
flutter run --dart-define=ESQUILO_API_URL=https://api.example.com
```
