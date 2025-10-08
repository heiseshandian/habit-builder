import 'package:flutter/material.dart';
import 'models/habit.dart';
import 'services/habit_store.dart';

class BuildMonthlyHistoryScreen extends StatefulWidget {
  final Habit habit;
  final HabitStore store;
  const BuildMonthlyHistoryScreen(
      {super.key, required this.habit, required this.store});

  @override
  State<BuildMonthlyHistoryScreen> createState() =>
      _BuildMonthlyHistoryScreenState();
}

class _BuildMonthlyHistoryScreenState extends State<BuildMonthlyHistoryScreen> {
  late DateTime _month; // first day of month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    return Scaffold(
      appBar: AppBar(
        title: Text('${habit.title} – Monthly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Previous month',
          ),
          Center(
              child: Text(
                  '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
            tooltip: 'Next month',
          ),
        ],
      ),
      body: _buildBody(habit, context),
    );
  }

  Widget _buildBody(Habit habit, BuildContext context) {
    // Build map of date -> completions
    final Map<DateTime, int> completions = {};
    for (final d in habit.history) {
      final ds = DateTime(d.day.year, d.day.month, d.day.day);
      if (ds.year == _month.year && ds.month == _month.month) {
        final c = d.avoids > 0 ? d.avoids : d.urges;
        if (c > 0) completions[ds] = c;
      }
    }
    // Include running current day if in month
    final today = DateTime.now();
    if (today.year == _month.year && today.month == _month.month) {
      if (habit.totalUrges > 0) {
        final ds = DateTime(today.year, today.month, today.day);
        completions[ds] = habit.totalUrges;
      }
    }

    // Generate weeks (Monday start). Find first Monday on/before month start.
    final firstDay = _month;
    final firstWeekStart =
        firstDay.subtract(Duration(days: (firstDay.weekday - 1))); // Monday
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final weeks = <_WeekBlock>[];
    DateTime cursor = firstWeekStart;
    while (!cursor.isAfter(lastDay)) {
      final days = List<DateTime>.generate(
          7, (i) => DateTime(cursor.year, cursor.month, cursor.day + i));
      weeks.add(_WeekBlock(days: days));
      cursor = cursor.add(const Duration(days: 7));
    }

    final weeklyGoal = habit.weeklyGoal ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: weeks.length,
      itemBuilder: (ctx, i) {
        final wb = weeks[i];
        final inMonthDays =
            wb.days.where((d) => d.month == _month.month).toList();
        final completedDayCount = wb.days
            .where((d) =>
                completions.containsKey(DateTime(d.year, d.month, d.day)))
            .length;
        bool hasAnyInMonth = inMonthDays.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: hasAnyInMonth
                ? Border.all(
                    color: completedDayCount > 0
                        ? Colors.green.shade700.withOpacity(0.4)
                        : Colors.grey.shade400.withOpacity(0.4),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatWeekLabel(wb.days.first),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(weeklyGoal == 0
                        ? '$completedDayCount days'
                        : '$completedDayCount/${weeklyGoal.clamp(0, 7)} days${completedDayCount >= weeklyGoal ? ' ⭐' : ''}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: wb.days.map((d) {
                    final isThisMonth = d.month == _month.month;
                    final key = DateTime(d.year, d.month, d.day);
                    final done = completions.containsKey(key);
                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Opacity(
                          opacity: isThisMonth ? 1 : 0.25,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: done
                                  ? Colors.green.shade600
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.shade700
                                      .withOpacity(done ? 0.6 : 0.2)),
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : Text('${d.day}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isThisMonth
                                              ? Colors.black
                                              : Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatWeekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    String m1 = start.month.toString().padLeft(2, '0');
    String m2 = end.month.toString().padLeft(2, '0');
    return '${start.year}-$m1/${start.day.toString().padLeft(2, '0')} – ${end.year}-$m2/${end.day.toString().padLeft(2, '0')}';
  }
}

class _WeekBlock {
  final List<DateTime> days;
  _WeekBlock({required this.days});
}
