# UnBrokie 💰

> AI-assisted Flutter finance tracker — track your spending, income, and big purchases across Android, iOS, and web.

---

## Screenshots

> _Will be provided soon._

---

## Features

- **Dashboard** — balance card with current-month income & expenses, category spending grid, recent transactions
- **History** — paginated transaction list with search, date-range filter, category filter, and infinite scroll
- **Calendar** — monthly calendar view with daily spend indicators and day-detail transaction list
- **Analytics** — period selector (this month / last 3 months / this year), income vs expense bar chart, spending-by-category donut chart
- **Settings** — category management (add, rename, delete), big buys tracker, timezone sync, manual reconciliation, log out
- **Offline support** — stale-while-revalidate caching with offline banner; mutations show a "no connection" snackbar
- **Optimistic UI** — new transactions appear instantly while the API request is in flight

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart 3.11+) |
| State management | Riverpod 3 (AsyncNotifier, family providers) |
| Navigation | go_router 17 with auth redirect guard |
| HTTP | `package:http` with exponential-backoff retry |
| Auth | JWT stored in `flutter_secure_storage` |
| Charts | fl_chart |
| Architecture | Domain / Data / Presentation (clean-ish layers) |
| Testing | flutter_test + Glados (property-based) |

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.38.4
- Dart SDK ≥ 3.11.4
- Android SDK (for Android builds) or Xcode (for iOS builds)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
# Debug on a connected device or emulator
flutter run

# Specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

### Build a release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Run tests

```bash
flutter test
```

---

## Backend

This is the backend repository [UnBrokie-backend](https://github.com/ifrunruhin12/UnBrokie-backend)

The app talks to a hosted REST API:

```
https://unbrokie-backend-production.up.railway.app/api/v1
```

All endpoints require a `Bearer` token except `/auth/login` and `/auth/register`. The client automatically retries failed requests up to 3 times with exponential backoff (1s → 2s → 4s) and maps HTTP status codes to typed exceptions (`AuthException`, `NotFoundException`, `ValidationException`, `ServerException`, `NetworkException`).
