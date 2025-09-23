import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/habit.dart';

class HabitStore {
  static const _key = 'habits_v1';
  List<Habit> _habits = [];

  List<Habit> get habits => _habits;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _habits = decodeHabits(raw);
      } catch (_) {
        _habits = [];
      }
    }
    _rotateAll();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeHabits(_habits));
  }

  void _rotateAll() {
    final now = DateTime.now();
    for (final h in _habits) {
      h.rotateIfNeeded(now);
    }
  }

  Future<Habit> addHabit(String title) async {
    final habit = Habit(
      id: _genId(),
      title: title,
      events: [],
      day: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      history: [],
    );
    _habits.add(habit);
    await save();
    return habit;
  }

  Future<void> addUrge(Habit habit) async {
    habit.rotateIfNeeded(DateTime.now());
    habit.addUrge();
    await save();
  }

  Future<void> addAvoid(Habit habit, int index) async {
    habit.addAvoidSuccess(index);
    await save();
  }

  Future<void> deleteEvent(Habit habit, int index) async {
    habit.removeEventAt(index);
    await save();
  }

  Future<void> renameHabit(Habit habit, String newTitle) async {
    habit.title = newTitle;
    await save();
  }

  String _genId() {
    final rnd = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
