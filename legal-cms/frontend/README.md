# Legal CMS — Frontend

Flutter web client for the Legal Case Management System.

**Live:** [https://law-cms-app.vercel.app](https://law-cms-app.vercel.app)  
**Login:** `advocate.sharma@legalcms.com` / `advocate123`

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
npx vercel deploy --prod
```

## API Base URL

The app reads `API_BASE_URL` from `--dart-define` at build time. Defaults to `/api` (relative) when not specified.

| Environment         | Value                                              |
|--------------------|----------------------------------------------------|
| Production (Vercel)| `https://law-cms-backend.vercel.app/api`           |
| Local backend      | `http://localhost:8000/api`                        |

## Key dependencies

- `dio` — HTTP client with JWT interceptor, file upload via `MultipartFile.fromBytes`
- `flutter_riverpod` — State management
- `go_router` — Navigation with `ShellRoute` for persistent layout
- `file_picker` — File selection (web + mobile), returns bytes directly for upload
- `flutter_secure_storage` — JWT token storage
- `fl_chart` — Dashboard charts
- `table_calendar` — Hearing calendar with day-tap filtering
