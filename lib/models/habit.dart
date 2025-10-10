import 'dart:convert';

enum HabitKind { avoid, build }

enum BuildFrequency { daily, weekly }

/// Represents a single tracked habit attempt (urge and optional success avoidance)
class HabitEvent {
  final DateTime timestamp;
  bool avoided; // whether a conscious successful avoidance (slash) was logged

  HabitEvent({required this.timestamp, this.avoided = false});

  Map<String, dynamic> toJson() => {
        't': timestamp.toIso8601String(),
        'a': avoided,
      };

  static HabitEvent fromJson(Map<String, dynamic> json) => HabitEvent(
        timestamp: DateTime.parse(json['t'] as String),
        avoided: json['a'] as bool? ?? false,
      );
}

class Habit {
  final String id; // stable uuid-ish
  String title;
  final List<HabitEvent> events; // events for today only (rotated each day)
  DateTime day; // start-of-day anchor for events list
  final List<DailySummary> history; // previous days
  HabitKind kind;
  int? dailyGoal; // for build daily
  int? weeklyGoal; // for build weekly (times per week)
  BuildFrequency buildFrequency;

  Habit({
    required this.id,
    required this.title,
    required this.events,
    required this.day,
    required this.history,
    this.kind = HabitKind.avoid,
    this.dailyGoal,
    this.weeklyGoal,
    this.buildFrequency = BuildFrequency.daily,
  });

  // For avoid habits: log urge.
  void addUrge() {
    events.add(HabitEvent(timestamp: DateTime.now()));
  }

  // For build habits: log completion (store as avoided=true for consistent success counting)
  void addCompletion() {
    events.add(HabitEvent(timestamp: DateTime.now(), avoided: true));
  }

  void addAvoidSuccess(int index) {
    if (index >= 0 && index < events.length) {
      events[index].avoided = true;
    }
  }

  void removeEventAt(int index) {
    if (index >= 0 && index < events.length) {
      events.removeAt(index);
    }
  }

  int get totalUrges =>
      events.length; // In build mode this is completion count (raw)
  int get totalAvoids => events
      .where((e) => e.avoided)
      .length; // In build mode should equal completions
  double get successRate {
    if (kind == HabitKind.build) {
      if (buildFrequency == BuildFrequency.daily) {
        if (dailyGoal == null || dailyGoal == 0) {
          return totalUrges == 0 ? 0 : 1;
        }
        return totalUrges / dailyGoal!.clamp(1, 1000000);
      } else {
        final stats = currentWeekCompletedDays();
        final goal = weeklyGoal ?? 0;
        if (goal == 0) return stats == 0 ? 0 : 1;
        return stats / goal.clamp(1, 7);
      }
    }
    return totalUrges == 0 ? 0 : totalAvoids / totalUrges;
  }

  int currentWeekCompletedDays() {
    // Count days (Sun-Sat) with >=1 completion (for build weekly)
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)); // Monday start
    final todayStart = DateTime(now.year, now.month, now.day);
    int count = 0;
    // Build map from history
    final Map<int, bool> dayHas = {};
    for (final d in history) {
      final ds = DateTime(d.day.year, d.day.month, d.day.day);
      if (!ds.isBefore(weekStart) && !ds.isAfter(todayStart)) {
        final completions = d.avoids > 0 ? d.avoids : d.urges;
        if (completions > 0) {
          final offset = ds.difference(weekStart).inDays;
          dayHas[offset] = true;
        }
      }
    }
    if (totalUrges > 0) {
      final offset = todayStart.difference(weekStart).inDays;
      dayHas[offset] = true;
    }
    count = dayHas.length;
    return count;
  }

  void rotateIfNeeded(DateTime now) {
    final startToday = DateTime(now.year, now.month, now.day);
    final startCurrent = DateTime(day.year, day.month, day.day);
    if (startToday.isAfter(startCurrent)) {
      // Only create a summary if there was any activity that day (events not empty).
      // Avoid storing 0/0 "empty" days in history to reduce clutter.
      if (events.isNotEmpty) {
        // push summary. For build habits we store goal as total 'urges' and completions as 'avoids'
        if (kind == HabitKind.build &&
            buildFrequency == BuildFrequency.daily &&
            dailyGoal != null &&
            dailyGoal! > 0) {
          history.add(
            DailySummary(
              day: startCurrent,
              urges: dailyGoal!,
              avoids: totalUrges, // completions
            ),
          );
        } else if (kind == HabitKind.build &&
            buildFrequency == BuildFrequency.weekly) {
          // For weekly build store raw completions both fields
          history.add(
            DailySummary(
              day: startCurrent,
              urges: totalUrges,
              avoids: totalUrges,
            ),
          );
        } else {
          history.add(
            DailySummary(
                day: startCurrent, urges: totalUrges, avoids: totalAvoids),
          );
        }
      }
      events.clear();
      day = startToday;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'events': events.map((e) => e.toJson()).toList(),
        'day': day.toIso8601String(),
        'history': history.map((h) => h.toJson()).toList(),
        'k': kind.name,
        if (dailyGoal != null) 'g': dailyGoal,
        if (weeklyGoal != null) 'wg': weeklyGoal,
        'bf': buildFrequency.name,
      };

  static Habit fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        title: json['title'] as String,
        events: (json['events'] as List<dynamic>? ?? [])
            .map((e) => HabitEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        day: DateTime.parse(json['day'] as String),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((h) => DailySummary.fromJson(h as Map<String, dynamic>))
            .toList(),
        kind: _parseKind(json['k']),
        dailyGoal: json['g'] as int?,
        weeklyGoal: json['wg'] as int?,
        buildFrequency: _parseBuildFrequency(json['bf']),
      );

  static HabitKind _parseKind(dynamic raw) {
    if (raw is String) {
      return raw == 'build' ? HabitKind.build : HabitKind.avoid;
    }
    return HabitKind.avoid;
  }

  static BuildFrequency _parseBuildFrequency(dynamic raw) {
    if (raw is String) {
      return raw == 'weekly' ? BuildFrequency.weekly : BuildFrequency.daily;
    }
    return BuildFrequency.daily;
  }
}

class DailySummary {
  final DateTime day; // start-of-day
  final int urges;
  final int avoids;

  DailySummary({required this.day, required this.urges, required this.avoids});

  double get rate => urges == 0 ? 0 : avoids / urges;

  Map<String, dynamic> toJson() => {
        'd': day.toIso8601String(),
        'u': urges,
        'a': avoids,
      };

  static DailySummary fromJson(Map<String, dynamic> json) => DailySummary(
        day: DateTime.parse(json['d'] as String),
        urges: json['u'] as int? ?? 0,
        avoids: json['a'] as int? ?? 0,
      );
}

String encodeHabits(List<Habit> habits) =>
    jsonEncode(habits.map((h) => h.toJson()).toList());

List<Habit> decodeHabits(String data) {
  final list = jsonDecode(data) as List<dynamic>;
  return list.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
}
