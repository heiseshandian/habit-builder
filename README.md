# Habit Builder

A minimal Flutter habit breaking tracker using an "index card" metaphor. Track urges (ticks) and successful avoidances (slashes) for each habit you are trying to quit.

## Features (MVP)

- Create a habit card with a title.
- Log an urge (tick ✓) when you feel the impulse.
- Log a success (slash /) when you ride out or avoid acting on the habit after an urge.
- Visual timeline of today's sequence (ticks and slashes paired visually per urge).
- Persistent local storage (shared_preferences) for habits and today's events.
- Reset day at midnight (auto rollover) while keeping historical daily summaries.

## Roadmap Ideas

- Streaks and success ratios.
- Export / import data.
- Notifications / urge coping tips.
- Dark mode & accessibility polishing.

## Getting Started

```sh
flutter pub get
flutter run
```

## Structure

```text
lib/
  main.dart
  models/
  services/
  screens/
  widgets/
```

## Notes

This MVP intentionally keeps scope small: no accounts, no networking, no tests (can be added later). Data is stored locally via shared_preferences; clearing app data will reset progress.
