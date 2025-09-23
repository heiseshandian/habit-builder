import 'dart:convert';

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

  Habit({
    required this.id,
    required this.title,
    required this.events,
    required this.day,
    required this.history,
  });

  void addUrge() {
    events.add(HabitEvent(timestamp: DateTime.now()));
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

  int get totalUrges => events.length;
  int get totalAvoids => events.where((e) => e.avoided).length;
  double get successRate => totalUrges == 0 ? 0 : totalAvoids / totalUrges;

  void rotateIfNeeded(DateTime now) {
    final startToday = DateTime(now.year, now.month, now.day);
    final startCurrent = DateTime(day.year, day.month, day.day);
    if (startToday.isAfter(startCurrent)) {
      // push summary
      history.add(
        DailySummary(day: startCurrent, urges: totalUrges, avoids: totalAvoids),
      );
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
      );
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
