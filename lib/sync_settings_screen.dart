import 'package:flutter/material.dart';
import 'services/habit_store.dart';
import 'services/remote_sync.dart';

class SyncSettingsScreen extends StatefulWidget {
  final HabitStore store;
  const SyncSettingsScreen({super.key, required this.store});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _tokenController = TextEditingController();
  final _gistController = TextEditingController();
  bool _busy = false;
  String? _message;
  final _sync = RemoteSyncService();

  @override
  void initState() {
    super.initState();
    _tokenController.text = widget.store.githubToken ?? '';
    _gistController.text = widget.store.gistId ?? '';
  }

  Future<void> _saveCreds() async {
    widget.store.updateAuth(
      token: _tokenController.text.trim().isEmpty
          ? null
          : _tokenController.text.trim(),
      gist: _gistController.text.trim().isEmpty
          ? null
          : _gistController.text.trim(),
    );
    await widget.store.save();
    setState(() {
      _message = 'Credentials saved locally.';
    });
  }

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sync.upload(widget.store);
      setState(() => _message = 'Upload successful');
    } catch (e) {
      setState(() => _message = 'Upload failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sync.download(widget.store);
      setState(() => _message = 'Download & merge successful');
    } catch (e) {
      setState(() => _message = 'Download failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.store.lastSynced;
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'GitHub Gist Sync (Experimental)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Provide a GitHub Personal Access Token (classic) with the "gist" scope. Optionally set an existing Gist ID to reuse; otherwise a new private gist will be created on first upload. Data is NOT encrypted — treat token & gist as sensitive.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'GitHub Token',
                hintText: 'ghp_xxx...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gistController,
              decoration: const InputDecoration(
                labelText: 'Gist ID (optional)',
                hintText: 'e.g. a1b2c3d4e5f6g7',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saveCreds,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_busy) const CircularProgressIndicator(),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.store.canSync ? _upload : null,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        widget.store.canSync && widget.store.gistId != null
                            ? _download
                            : null,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (last != null) Text('Last sync: ${last.toLocal()}'),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.toLowerCase().contains('fail')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 40),
            const Text('Limitations:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
                '• Automatic download happens once at startup if configured.'),
            const Text('• Automatic upload after edits (debounced ~2s).'),
            const Text('• Last writer wins (no merge of concurrent edits).'),
            const Text(
                '• Token stored locally in plain text (SharedPreferences).'),
          ],
        ),
      ),
    );
  }
}
