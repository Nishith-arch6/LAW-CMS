# Legal CMS — Frontend

Flutter web client for the Legal Case Management System.

## Build

```bash
flutter pub get
flutter build web --dart-define=API_BASE_URL=https://law-cms-backend.vercel.app/api --release
```

## Run locally

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```

## Deploy

```bash
cd build/web
npx vercel deploy --prod --token $VERCEL_TOKEN
```

## Key dependencies

- `dio` — HTTP client with JWT interceptor
- `flutter_riverpod` — State management
- `go_router` — Navigation
- `file_picker` — File selection (web + mobile)
- `flutter_secure_storage` — JWT token storage
- `fl_chart` — Dashboard charts
