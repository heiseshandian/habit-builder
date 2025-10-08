import 'package:flutter/material.dart';
import 'services/habit_store.dart';
import 'models/habit.dart';
import 'history_screen.dart';
import 'build_monthly_history_screen.dart';
import 'sync_settings_screen.dart';
import 'services/remote_sync.dart';

void main() {
  runApp(const HabitApp());
}

class HabitApp extends StatefulWidget {
  const HabitApp({super.key});

  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> {
  final store = HabitStore();
  bool _loaded = false;
  final _remote = RemoteSyncService();

  @override
  void initState() {
    super.initState();
    store.attachRemote(_remote);
    store.load().then((_) async {
      // Attempt auto download (will silently ignore errors)
      await store.autoDownloadIfConfigured();
      if (mounted) {
        setState(() => _loaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Builder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: !_loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : HabitListScreen(store: store),
    );
  }
}

class HabitListScreen extends StatefulWidget {
  final HabitStore store;
  const HabitListScreen({super.key, required this.store});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  bool _fabMenuOpen = false;

  void _toggleFabMenu() {
    setState(() => _fabMenuOpen = !_fabMenuOpen);
  }

  Future<void> _createAvoidHabit() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Avoid Habit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'e.g. Quit Sugar',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true) {
      final title = controller.text.trim();
      if (title.isNotEmpty) {
        await widget.store.addHabit(title, kind: HabitKind.avoid);
        setState(() {});
      }
    }
    if (mounted) _toggleFabMenu();
  }

  Future<void> _createBuildHabit() async {
    final titleController = TextEditingController();
    final goalController = TextEditingController(); // daily goal
    final weeklyGoalController = TextEditingController();
    BuildFrequency frequency = BuildFrequency.daily;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Build Habit'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Drink Water',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<BuildFrequency>(
                        value: frequency,
                        decoration: const InputDecoration(labelText: 'Mode'),
                        items: const [
                          DropdownMenuItem(
                              value: BuildFrequency.daily,
                              child: Text('Daily')),
                          DropdownMenuItem(
                              value: BuildFrequency.weekly,
                              child: Text('Weekly')),
                        ],
                        onChanged: (v) => setLocal(() {
                          frequency = v ?? BuildFrequency.daily;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (frequency == BuildFrequency.daily)
                  TextField(
                    controller: goalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Daily Goal (optional)', hintText: 'e.g. 8'),
                  )
                else
                  TextField(
                    controller: weeklyGoalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Weekly Goal (days, optional)',
                        hintText: 'e.g. 4'),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    frequency == BuildFrequency.daily
                        ? 'Goal = completions per day.'
                        : 'Goal = days per week with at least 1 completion.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true) {
      final title = titleController.text.trim();
      if (title.isNotEmpty) {
        final daily = int.tryParse(goalController.text.trim());
        final weekly = int.tryParse(weeklyGoalController.text.trim());
        await widget.store.addHabit(
          title,
          kind: HabitKind.build,
          dailyGoal: frequency == BuildFrequency.daily ? daily : null,
          weeklyGoal: frequency == BuildFrequency.weekly ? weekly : null,
          buildFrequency: frequency,
        );
        setState(() {});
      }
    }
    if (mounted) _toggleFabMenu();
  }

  String _buildProgressSubtitle(Habit h) {
    if (h.kind == HabitKind.build) {
      if (h.buildFrequency == BuildFrequency.daily) {
        if (h.dailyGoal == null || h.dailyGoal == 0) {
          return '${h.totalUrges} completions';
        }
        final pct = (h.successRate * 100).clamp(0, 100).toStringAsFixed(0);
        return '${h.totalUrges}/${h.dailyGoal} done • $pct%';
      } else {
        final completedDays = h.currentWeekCompletedDays();
        final goal = h.weeklyGoal ?? 0;
        final pct = (h.successRate * 100).clamp(0, 100).toStringAsFixed(0);
        return goal == 0
            ? '$completedDays days this week'
            : '$completedDays/${goal.clamp(0, 7)} days • $pct%';
      }
    }
    return '${h.totalAvoids}/${h.totalUrges} avoided today';
  }

  @override
  Widget build(BuildContext context) {
    final habits = widget.store.habits;
    return Scaffold(
      appBar: AppBar(title: const Text('Habits'), actions: [
        IconButton(
            tooltip: 'Sync / Settings',
            onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SyncSettingsScreen(store: widget.store)),
                ).then((_) => setState(() {})),
            icon: const Icon(Icons.sync)),
      ]),
      body: ListView.builder(
        itemCount: habits.length,
        itemBuilder: (context, i) {
          final h = habits[i];
          final iconData =
              h.kind == HabitKind.build ? Icons.flash_on : Icons.block;
          final iconColor = h.kind == HabitKind.build
              ? Colors.teal.shade700
              : Colors.deepOrange.shade600;
          return Dismissible(
            key: ValueKey(h.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.redAccent,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete habit?'),
                      content: const Text(
                          'This will remove the habit and all its history. This cannot be undone.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  ) ??
                  false;
            },
            onDismissed: (_) async {
              await widget.store.deleteHabit(h);
              setState(() {});
            },
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.15),
                child: Icon(iconData, color: iconColor),
              ),
              title: Text(h.title),
              subtitle: h.kind == HabitKind.avoid
                  ? Text('${h.totalAvoids}/${h.totalUrges} avoided today')
                  : Text(_buildProgressSubtitle(h)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      HabitDetailScreen(store: widget.store, habit: h),
                ),
              ).then((_) => setState(() {})),
            ),
          );
        },
      ),
      floatingActionButton: _buildFabMenu(),
    );
  }

  Widget _buildFabMenu() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_fabMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleFabMenu,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.shrink(),
            ),
          ),
        if (_fabMenuOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 80.0, right: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniFab(
                  color: Colors.teal.shade700,
                  icon: Icons.flash_on,
                  label: 'Build Habit',
                  onTap: _createBuildHabit,
                ),
                const SizedBox(height: 12),
                _MiniFab(
                  color: Colors.deepOrange.shade600,
                  icon: Icons.block,
                  label: 'Avoid Habit',
                  onTap: _createAvoidHabit,
                ),
              ],
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _toggleFabMenu,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, anim) =>
                  RotationTransition(turns: anim, child: c),
              child: Icon(_fabMenuOpen ? Icons.close : Icons.add,
                  key: ValueKey(_fabMenuOpen)),
            ),
          ),
        ),
      ],
    );
  }
}

class HabitDetailScreen extends StatefulWidget {
  final HabitStore store;
  final Habit habit;
  const HabitDetailScreen({
    super.key,
    required this.store,
    required this.habit,
  });

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  void _addUrge() async {
    await widget.store.addUrge(widget.habit);
    setState(() {});
  }

  void _addAvoid(int index) async {
    await widget.store.addAvoid(widget.habit, index);
    setState(() {});
  }

  void _addCompletion() async {
    await widget.store.addCompletion(widget.habit);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final events = habit.events;
    final isBuild = habit.kind == HabitKind.build;
    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => _openHistory(habit),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isBuild)
                  Text(
                    'Today: ${habit.totalAvoids}/${habit.totalUrges} avoided',
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                else
                  Text(
                    _buildHeaderProgress(habit),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                Text(
                  isBuild
                      ? 'Progress: ${(habit.successRate * 100).clamp(0, 100).toStringAsFixed(0)}%'
                      : 'Rate: ${(habit.successRate * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final e = events[i];
                return Dismissible(
                  key: ValueKey('${e.timestamp.millisecondsSinceEpoch}-$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete entry?'),
                            content: Text(isBuild
                                ? 'This will remove the completion.'
                                : 'This will remove the logged urge (and its avoidance if any).'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) async {
                    await widget.store.deleteEvent(habit, i);
                    setState(() {});
                  },
                  child: ListTile(
                    title: Text(
                        TimeOfDay.fromDateTime(e.timestamp).format(context)),
                    trailing: isBuild
                        ? const Text('✅', style: TextStyle(fontSize: 28))
                        : e.avoided
                            ? const Text('✅', style: TextStyle(fontSize: 28))
                            : IconButton(
                                icon: const Text('❌',
                                    style: TextStyle(fontSize: 28)),
                                onPressed: () => _addAvoid(i),
                              ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBuild ? _addCompletion : _addUrge,
                      icon: const Icon(Icons.add),
                      label:
                          Text(isBuild ? 'Log Completion (✓)' : 'Log Urge (✓)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildHeaderProgress(Habit habit) {
    if (habit.buildFrequency == BuildFrequency.daily) {
      if (habit.dailyGoal == null || habit.dailyGoal == 0) {
        return 'Completions: ${habit.totalUrges}';
      }
      return 'Today: ${habit.totalUrges}/${habit.dailyGoal} completed';
    } else {
      final days = habit.currentWeekCompletedDays();
      final goal = habit.weeklyGoal ?? 0;
      if (goal == 0) return 'Days this week: $days';
      return 'Week: $days/${goal.clamp(0, 7)} days';
    }
  }

  void _openHistory(Habit habit) {
    if (habit.kind == HabitKind.build) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuildMonthlyHistoryScreen(
            habit: habit,
            store: widget.store,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitHistoryScreen(
          habit: habit,
          store: widget.store,
        ),
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  const _MiniFab(
      {required this.onTap,
      required this.icon,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(label, style: theme.textTheme.labelLarge),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: '${label}_mini',
              backgroundColor: color,
              onPressed: onTap,
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }
}
