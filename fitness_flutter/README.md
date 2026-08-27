# Fitness Tracker — Flutter App

The Flutter frontend for the Fitness Tracker. See the [main README](../README.md) for full project details.

## Quick Start

```bash
flutter pub get
flutter run
```

## Requirements

- Flutter SDK ≥ 3.41
- iOS 26+ simulator/device (for Liquid Glass UI)
- Backend running on localhost:8000 (see `../backend/`)

## Structure

```
lib/
├── config/       Theme, router, API config
├── models/       Data classes
├── providers/    Riverpod state management
├── screens/      Feature screens
├── services/     API layer
├── utils/        Helpers
└── widgets/      Shared components
```
