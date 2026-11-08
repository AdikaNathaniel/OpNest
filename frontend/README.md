# OpNest app (Flutter)

Browse UG International Programmes Office study-abroad opportunities served by
the OpNest backend in `../backend`.

## Run

Start the backend first (`npm run start:dev` in `../backend`), then:

```
flutter run -d chrome      # web
flutter run -d windows     # Windows desktop
flutter run                # a connected phone or emulator
```

The app talks to `http://localhost:3000` (or `http://10.0.2.2:3000` on the
Android emulator, which is how it reaches your PC). For a real phone or a
deployed backend, pass the address:

```
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
flutter build apk --dart-define=API_BASE_URL=https://your-server.example.com
```

## Release notes

Android allows plain `http://` (`usesCleartextTraffic`) and iOS allows local
network `http://` so development works without HTTPS. Once the backend is on
HTTPS, remove `usesCleartextTraffic` from `android/app/src/main/AndroidManifest.xml`.

## Structure

- `lib/api/` – HTTP client for the backend
- `lib/models/` – `Opportunity` model
- `lib/screens/` – list (search, open/closed, level filters) and detail screens
- `lib/widgets/` – cards and the deadline countdown badge
- `test/app_test.dart` – widget tests with a fake server
