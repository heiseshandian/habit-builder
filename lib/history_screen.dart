import 'package:flutter/material.dart';
import 'models/habit.dart';
import 'services/habit_store.dart';

/// Screen to display historical daily summaries for a habit.
class HabitHistoryScreen extends StatefulWidget {
  final Habit habit;
  final HabitStore store;
  const HabitHistoryScreen(
      {super.key, required this.habit, required this.store});

  @override
  State<HabitHistoryScreen> createState() => _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  late Habit _habit;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    // Ensure rotation so history is up-to-date if user crossed midnight while app open.
    final beforeDay = _habit.day;
    _habit.rotateIfNeeded(DateTime.now());
    if (beforeDay != _habit.day) {
      // Persist rotation side-effect.
      widget.store.save();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Copy history so we don't mutate underlying list when reversing.
    final List<DailySummary> past = List.of(_habit.history);
    past.sort((a, b) => b.day.compareTo(a.day)); // latest first

    // Today's running summary (not yet part of history list until rotation)
    final todaySummary = DailySummary(
      day: DateTime(_habit.day.year, _habit.day.month, _habit.day.day),
      urges: _habit.totalUrges,
      avoids: _habit.totalAvoids,
    );

    final items = [todaySummary, ...past];

    return Scaffold(
      appBar: AppBar(
        title: Text('History – ${_habit.title}'),
      ),
      body: items.length <= 1 && past.isEmpty
          ? const Center(child: Text('No history yet. Start logging urges!'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = items[i];
                final isToday = i == 0;
                final rate = s.rate;
                return ListTile(
                  title: Text(isToday
                      ? 'Today (${_formatDate(s.day)})'
                      : _formatDate(s.day)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${s.avoids}/${s.urges} avoided${s.urges == 0 ? '' : '  •  ${(rate * 100).toStringAsFixed(0)}%'}'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: s.urges == 0 ? 0 : rate,
                        minHeight: 6,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isToday
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    child: Text(
                      s.urges == 0
                          ? '0%'
                          : '${(rate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
