# Workout App

A Flutter iOS app for tracking gym progress. Log your workouts, manage routines, and visualize monthly training history.

## Features

- **Daily workout logging** — weights, cardio, timed sets (abs/stretching), and bodyweight exercises
- **Routine management** — create routines manually or import from a PDF
- **Exercise database** — powered by the [WGER](https://wger.de) open source API (descriptions, images, muscle groups)
- **Progress calendar** — monthly view with per-day and per-exercise filters
- **Unit toggle** — switch between kg and lbs at any time

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.x (iOS primary) |
| State management | Riverpod 2.x |
| Local database | Isar 3.x |
| Navigation | go_router |
| HTTP | Dio |
| Exercise DB | WGER public API |
| PDF import | pdfrx |
| Animations | flutter_animate |

## Getting Started

### Prerequisites

- Flutter 3.44+ (`flutter --version`)
- Xcode 15+ (for iOS builds)
- CocoaPods (`pod --version`)

### Setup

```bash
flutter pub get
flutter run
```

### Code generation (after schema changes)

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Project Structure

```
lib/
├── core/          # DB init, theme, router, constants
├── features/      # today, workout, routines, progress, profile
└── shared/        # models, services, widgets
```

## Architecture

- **Local-first**: all data lives in Isar on-device; cloud sync planned for a future phase
- **Offline-ready**: WGER exercise data is cached locally with a 7-day TTL
- **Extensible**: PDF parser is a pluggable module — regex today, AI-assisted later

## License

Private project.
