import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/habit.dart';

class HabitStore {
  static const _key = 'habits_v1';
  static const _syncKey = 'habits_sync_meta_v1';
  List<Habit> _habits = [];

  // Remote sync metadata
  String? gistId; // GitHub Gist ID
  String? githubToken; // Personal access token (classic, gist scope)
  DateTime? lastSynced; // last successful sync time

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
    // load sync metadata
    final syncRaw = prefs.getString(_syncKey);
    if (syncRaw != null) {
      try {
        final parts = syncRaw.split('|');
        gistId = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
        githubToken = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
        if (parts.length > 2 && parts[2].isNotEmpty) {
          lastSynced = DateTime.tryParse(parts[2]);
        }
      } catch (_) {
        gistId = null;
        githubToken = null;
      }
    }
    _rotateAll();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeHabits(_habits));
    final meta = [
      gistId ?? '',
      githubToken ?? '',
      lastSynced?.toIso8601String() ?? ''
    ].join('|');
    await prefs.setString(_syncKey, meta);
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

  // --- Remote sync helpers (implemented in remote_sync.dart) ---
  bool get canSync => githubToken != null && githubToken!.isNotEmpty;
  void updateAuth({String? token, String? gist}) {
    if (token != null) githubToken = token;
    if (gist != null) gistId = gist;
  }
}
