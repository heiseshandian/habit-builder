import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import '../models/habit.dart';
import 'remote_sync.dart';

class HabitStore {
  static const _key = 'habits_v1';
  static const _syncKey = 'habits_sync_meta_v1';
  List<Habit> _habits = [];

  // Remote sync metadata
  String? gistId; // GitHub Gist ID
  String? githubToken; // Personal access token (classic, gist scope)
  DateTime? lastSynced; // last successful sync time
  RemoteSyncService? _remote; // attached remote service for auto sync
  Timer? _uploadDebounce;
  bool _uploadInProgress = false;

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

  Future<Habit> addHabit(String title,
      {HabitKind kind = HabitKind.avoid,
      int? dailyGoal,
      int? weeklyGoal,
      BuildFrequency buildFrequency = BuildFrequency.daily}) async {
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
      kind: kind,
      dailyGoal: dailyGoal,
      weeklyGoal: weeklyGoal,
      buildFrequency: buildFrequency,
    );
    _habits.add(habit);
    await save();
    _scheduleAutoUpload();
    return habit;
  }

  Future<void> addUrge(Habit habit) async {
    habit.rotateIfNeeded(DateTime.now());
    habit.addUrge();
    await save();
    _scheduleAutoUpload();
  }

  Future<void> addCompletion(Habit habit) async {
    habit.rotateIfNeeded(DateTime.now());
    habit.addCompletion();
    await save();
    _scheduleAutoUpload();
  }

  Future<void> addAvoid(Habit habit, int index) async {
    habit.addAvoidSuccess(index);
    await save();
    _scheduleAutoUpload();
  }

  Future<void> deleteEvent(Habit habit, int index) async {
    habit.removeEventAt(index);
    await save();
    _scheduleAutoUpload();
  }

  Future<void> renameHabit(Habit habit, String newTitle) async {
    habit.title = newTitle;
    await save();
    _scheduleAutoUpload();
  }

  Future<void> deleteHabit(Habit habit) async {
    _habits.removeWhere((h) => h.id == habit.id);
    await save();
    _scheduleAutoUpload();
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

  void attachRemote(RemoteSyncService remote) {
    _remote = remote;
  }

  void _scheduleAutoUpload() {
    if (!canSync || _remote == null) return;
    // Coalesce rapid successive changes (1s debounce)
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(const Duration(seconds: 1), () async {
      if (_uploadInProgress) return; // skip if still running previous
      _uploadInProgress = true;
      try {
        await _remote!.upload(this);
      } catch (_) {
        // swallow errors silently for now; could surface later
      } finally {
        _uploadInProgress = false;
      }
    });
  }

  Future<void> autoDownloadIfConfigured() async {
    if (!canSync || gistId == null || _remote == null) return;
    try {
      await _remote!.download(this);
    } catch (_) {
      // ignore failures (stay with local data)
    }
  }

  void dispose() {
    _uploadDebounce?.cancel();
  }
}
