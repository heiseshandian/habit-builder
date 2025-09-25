import 'package:flutter/material.dart';
import 'services/habit_store.dart';
import 'models/habit.dart';
import 'history_screen.dart';
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
  Future<void> _addHabitDialog() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Habit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Habit (e.g. Quit Sugar)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await widget.store.addHabit(title);
      setState(() {});
    }
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
          return ListTile(
            title: Text(h.title),
            subtitle: Text('${h.totalAvoids}/${h.totalUrges} avoided today'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    HabitDetailScreen(store: widget.store, habit: h),
              ),
            ).then((_) => setState(() {})),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHabitDialog,
        child: const Icon(Icons.add),
      ),
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

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final events = habit.events;
    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HabitHistoryScreen(
                  habit: habit,
                  store: widget.store,
                ),
              ),
            ),
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
                Text(
                  'Today: ${habit.totalAvoids}/${habit.totalUrges} avoided',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Rate: ${(habit.successRate * 100).toStringAsFixed(0)}%'),
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
                            content: const Text(
                                'This will remove the logged urge (and its avoidance if any).'),
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
                    trailing: e.avoided
                        ? const Text('✅', style: TextStyle(fontSize: 28))
                        : IconButton(
                            icon:
                                const Text('❌', style: TextStyle(fontSize: 28)),
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
                      onPressed: _addUrge,
                      icon: const Icon(Icons.add),
                      label: const Text('Log Urge (✓)'),
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
}
