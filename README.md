# Habit Builder

A focused Flutter app for both breaking bad habits ("avoid" mode) and building new ones ("build" mode). Originally a minimal urge tracker, it now supports daily & weekly build goals, historical analytics, and optional cross‑device sync via GitHub Gists—while staying lightweight and completely local-first.

## Key Features

### Habit Types

- **Avoid Habit**: Log urges (✓) and mark successful avoidance (/ or ✅) to measure restraint rate.
- **Build Habit**: Log completions (✓). Supports:
  - Daily goals (e.g. meditate 2 times today)
  - Weekly goals (e.g. exercise 3 days per week, counts distinct active days Mon–Sun)

### Logging & Progress

- Dual floating action menu to add either an Avoid or Build habit.
- Quick single-tap logging (urge or completion).
- Per-habit success metrics (daily completion %, weekly days met, or avoidance rate).
- Swipe left inside habit detail view to delete individual events.

### History Views

- **Daily History Screen** for avoid habits (shows past daily summaries).
- **Monthly Build History** for all build habits (daily & weekly):
  - Month navigation (← / →)
  - Weekly rows (Mon–Sun) with check marks for days completed
  - Neutral styling (no background coloring) per latest design

### Goals & Rotation

- Midnight rollover persists a `DailySummary` entry automatically.
- Weekly build success rate counts unique days with ≥1 completion.
- Open‑ended goals (0 or null) are treated as qualitative tracking (always 100% if any activity for that period).

### Cross‑Device Sync (Optional)

- Manual and auto sync using a **private GitHub Gist**.
- Auto-download on startup (if configured) + debounced auto-upload after changes.
- Stores metadata locally (gist ID, token, last sync timestamp).
- Network-safe: handles offline & permission (macOS sandbox) errors gracefully.

### UI & Usability

- Type icon on each habit row (flash for build, block for avoid).
- Swipe-to-delete a habit (confirmation required) including its entire history.
- Adaptive progress subtitles for daily vs weekly build modes.

### Persistence

- Local JSON stored via `shared_preferences` (keyed by `habits_v1`).
- Data model includes: events (today), rolling history (prior days), habit type, daily/weekly goals, build frequency.

## Screens Overview

| Screen                  | Purpose                                                        |
| ----------------------- | -------------------------------------------------------------- |
| Habit List              | Overview of all habits, quick progress snapshot, creation menu |
| Habit Detail            | Log events & review today’s timeline                           |
| Monthly History (Build) | Calendar-like weekly rows with completion check marks          |
| Daily History (Avoid)   | Scrollable list of prior days with avoidance ratios            |
| Sync Settings           | Configure GitHub token & gist; manual upload/download          |

## Sync Setup (GitHub Gist)

1. Create a classic personal access token (PAT) with `gist` scope.
2. (Optional) Manually create a private Gist; leave it empty or with a placeholder file.
3. In the app: open the Sync / Settings screen (top app bar icon) and paste:
   - Token
   - Gist ID (from the gist URL, e.g. `https://gist.github.com/<user>/<gistId>`)
4. Tap Download (if gist already has data) or Upload (to initialize remote state).
5. Auto sync will run after subsequent habit changes.

Security note: Token & gist ID are stored locally (not encrypted). Revoke the token anytime in GitHub settings. Use a token with only `gist` scope.

## Getting Started

```sh
flutter pub get
flutter run
```

Run on macOS / Windows / Linux / Web / iOS / Android (Flutter multi-platform). For macOS, ensure the app has network entitlement (already included in project).

## Project Structure

```text
lib/
  main.dart              # UI scaffolding & navigation
  models/habit.dart      # Core data structures & serialization
  services/habit_store.dart  # Persistence & sync triggers
  services/remote_sync.dart  # GitHub Gist integration
  history_screen.dart    # Avoid habit history
  build_monthly_history_screen.dart # Build habit monthly view
  sync_settings_screen.dart # Token & gist management UI
```

## Data Model Snapshot

| Field                  | Description                                           |
| ---------------------- | ----------------------------------------------------- |
| events                 | Today’s raw events (urge/completion + avoided flag)   |
| history                | Prior day summaries (rate reconstruction + analytics) |
| kind                   | `avoid` or `build`                                    |
| buildFrequency         | `daily` or `weekly` for build habits                  |
| dailyGoal / weeklyGoal | Optional target thresholds                            |

Rotation logic consolidates today’s events into a `DailySummary` at day change; weekly stats derive from distinct active days.

## Deletion Behavior

- Deleting a habit removes all its local & synced history (if you sync afterward).
- Event deletion only affects the current day (past summaries remain immutable).

## Limitations / Known Tradeoffs

- No conflict merge: last uploader wins (gist is a single file snapshot).
- No encryption (local or remote) beyond GitHub’s private gist access control.
- No multi-user collaboration semantics.

## Roadmap Candidates

- Undo snackbar for deletions.
- Editable habit properties after creation.
- Streak tracking & calendar heat maps.
- Export / Import (JSON).
- Notifications / reminders.
- Theming & accessibility passes.
- Optional encrypted storage layer.

## Contributing

Open an issue or fork and submit a PR. Keep scope small & UX uncluttered.

## License

MIT (add a LICENSE file if distributing publicly).

---

Built to stay fast, clear, and encouragement‑oriented. Track, reflect, improve. ✅
