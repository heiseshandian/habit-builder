import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/habit.dart';
import 'habit_store.dart';

/// Lightweight sync to a private GitHub Gist.
/// Not end-to-end encrypted. Token must have `gist` scope.
class RemoteSyncService {
  static const filename = 'habits.json';

  Future<void> upload(HabitStore store) async {
    if (!store.canSync) {
      throw Exception('Missing GitHub token');
    }
    final body = encodeHabits(store.habits);
    if (store.gistId == null) {
      // create new private gist
      final res = await http.post(
        Uri.parse('https://api.github.com/gists'),
        headers: _headers(store.githubToken!),
        body: jsonEncode({
          'description': 'Habit Builder sync',
          'public': false,
          'files': {
            filename: {'content': body}
          },
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        store.gistId = data['id'] as String?;
        store.lastSynced = DateTime.now();
        await store.save();
      } else {
        throw Exception('Failed to create gist (${res.statusCode})');
      }
    } else {
      final res = await http.patch(
        Uri.parse('https://api.github.com/gists/${store.gistId}'),
        headers: _headers(store.githubToken!),
        body: jsonEncode({
          'files': {
            filename: {'content': body}
          },
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        store.lastSynced = DateTime.now();
        await store.save();
      } else if (res.statusCode == 404) {
        // gist missing -> reset id so next upload creates new
        store.gistId = null;
        await upload(store); // retry create
      } else {
        throw Exception('Failed to update gist (${res.statusCode})');
      }
    }
  }

  Future<void> download(HabitStore store) async {
    if (!store.canSync || store.gistId == null) {
      throw Exception('Not configured for sync');
    }
    final res = await http.get(
      Uri.parse('https://api.github.com/gists/${store.gistId}'),
      headers: _headers(store.githubToken!),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final files = data['files'] as Map<String, dynamic>?;
      final file = files?[filename] as Map<String, dynamic>?;
      final content = file?['content'] as String?;
      if (content == null) {
        throw Exception('Remote gist missing $filename');
      }
      try {
        final habits = decodeHabits(content);
        store.habits
          ..clear()
          ..addAll(habits);
        store.lastSynced = DateTime.now();
        await store.save();
      } catch (e) {
        throw Exception('Failed to parse remote data: $e');
      }
    } else if (res.statusCode == 404) {
      throw Exception('Gist not found. Maybe deleted?');
    } else {
      throw Exception('Failed to fetch gist (${res.statusCode})');
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'habit-builder-app',
      };
}
