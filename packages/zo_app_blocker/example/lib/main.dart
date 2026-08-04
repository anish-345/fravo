import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:zo_app_blocker/zo_app_blocker.dart';

@pragma('vm:entry-point')
void onBlockScreenRequested() {
  ZoBlockScreenRunner.run(
    builder: (context) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (context.appIcon != null)
                Image.memory(
                  context.appIcon!,
                  width: 100,
                  height: 100,
                ),
              const SizedBox(height: 24),
              Text(
                '${context.appName ?? 'App'} is Blocked!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You have customized this screen using Flutter.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: context.onDismiss,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Exit'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final granted = await context.onRequestTemporarySessionUnlock?.call() ?? false;
                  if (!granted) {
                    // Could show a snackbar or dialog if unlock failed
                  }
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock for this session (Cost: 50 coins)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ZoAppBlocker.instance.initialize(
    blockScreenCallback: onBlockScreenRequested,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zo App Blocker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _plugin = ZoAppBlocker.instance;
  String _usageStatsStatus = 'Unknown';
  String _overlayStatus = 'Unknown';
  List<Map<String, dynamic>> _blockedApps = [];
  List<AppTimeLimit> _timeLimits = [];

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadBlockedApps();
    _loadTimeLimits();

    _plugin.setNotificationConfig(
      notificationBannerTitle: 'Stop Right There!',
      notificationBannerDescription: 'You blocked this app. Get back to work!',
    );
  }

  Future<void> _checkPermission() async {
    final usageStatus = await _plugin.checkUsageStatsPermission();
    final overlayStatus = await _plugin.checkOverlayPermission();
    setState(() {
      _usageStatsStatus = usageStatus;
      _overlayStatus = overlayStatus;
    });
  }

  Future<void> _loadBlockedApps() async {
    final apps = await _plugin.getBlockedApps();
    setState(() => _blockedApps = apps);
  }

  Future<void> _loadTimeLimits() async {
    final limits = await _plugin.getAppTimeLimits();
    setState(() => _timeLimits = limits);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await _plugin.requestNotificationPermission();
      final notifStatus = await _plugin.checkNotificationPermission();
      if (notifStatus != 'granted') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is required for the background service.',
            ),
          ),
        );
      }
    }
    await _plugin.requestUsageStatsPermission();
    await _plugin.requestOverlayPermission();
    _checkPermission();
  }

  Future<void> _selectAndBlockApps() async {
    try {
      final apps = await _plugin.getApps();

      if (Platform.isIOS) {
        _loadBlockedApps();
        return;
      }

      if (apps.isEmpty) return;
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select an app to block',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      leading: _AppIcon(packageName: app['packageName'] ?? ''),
                      title: Text(app['appName'] ?? ''),
                      subtitle: Text(app['packageName'] ?? ''),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final scaffold = ScaffoldMessenger.of(context);
                        await _plugin.blockApps([app['packageName']]);
                        if (!mounted) return;
                        nav.pop();
                        scaffold.showSnackBar(
                          SnackBar(content: Text('Blocked ${app['appName']}')),
                        );
                        _loadBlockedApps();
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Shows an app picker and then prompts for a minute limit.
  Future<void> _showSetTimeLimitSheet() async {
    final apps = await _plugin.getApps();
    if (apps.isEmpty || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SetTimeLimitSheet(apps: apps, plugin: _plugin),
    ).then((_) => _loadTimeLimits());
  }

  Future<void> _showActivityLog() async {
    final log = await _plugin.getBlockActivityLog();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Block Activity Log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _plugin.clearBlockActivityLog();
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showActivityLog();
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: log.isEmpty
                  ? const Center(child: Text('No activity yet.'))
                  : ListView.builder(
                      itemCount: log.length,
                      itemBuilder: (context, index) {
                        final entry = log[index];
                        final packageName = entry['packageName'] as String;
                        final timestamp = entry['timestamp'] as int;
                        final date =
                            DateTime.fromMillisecondsSinceEpoch(timestamp);
                        return ListTile(
                          leading: _AppIcon(packageName: packageName, size: 32),
                          title: Text(packageName),
                          subtitle:
                              Text('${date.toLocal()}'.split('.')[0]),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zo App Blocker Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadBlockedApps();
          await _loadTimeLimits();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Permission card ──────────────────────────────────────────
            _SectionCard(
              title: 'Permissions',
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(
                    (_usageStatsStatus == 'granted' && _overlayStatus == 'granted')
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: (_usageStatsStatus == 'granted' && _overlayStatus == 'granted')
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: Text('Usage Stats: $_usageStatsStatus\nOverlay: $_overlayStatus'),
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Request Permissions'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Block Apps card ──────────────────────────────────────────
            _SectionCard(
              title: 'App Blocking',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selectAndBlockApps,
                        icon: const Icon(Icons.block),
                        label: const Text('Block an App'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final scaffold = ScaffoldMessenger.of(context);
                          await _plugin.unblockAll();
                          if (!mounted) return;
                          scaffold.showSnackBar(
                            const SnackBar(
                                content: Text('All apps unblocked')),
                          );
                          _loadBlockedApps();
                        },
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Unblock All'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Blocked Apps (${_blockedApps.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: _showActivityLog,
                      child: const Text('Activity Log'),
                    ),
                  ],
                ),
                if (_blockedApps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No apps currently blocked.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...(_blockedApps.map(
                    (app) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: _AppIcon(
                          packageName: app['packageName'] ?? '', size: 36),
                      title: Text(app['appName'] ?? 'Unknown'),
                      subtitle: Text(
                        app['packageName'] ?? '',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () async {
                          await _plugin
                              .unblockApps([app['packageName'] as String]);
                          _loadBlockedApps();
                        },
                      ),
                    ),
                  )),
              ],
            ),
            const SizedBox(height: 16),

            // ── Time Limits card ─────────────────────────────────────────
            _SectionCard(
              title: '⏱  Daily Time Limits',
              children: [
                const Text(
                  'Set how many minutes per day a user can spend in an app. '
                  'The notification updates live with the countdown. '
                  'When the budget hits 0, the app is blocked automatically.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _showSetTimeLimitSheet,
                  icon: const Icon(Icons.timer),
                  label: const Text('Set Time Limit for an App'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadTimeLimits,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Usage Stats'),
                ),
                const SizedBox(height: 12),
                if (_timeLimits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No time limits configured.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...(_timeLimits.map(
                    (limit) => _TimeLimitTile(
                      limit: limit,
                      plugin: _plugin,
                      onChanged: _loadTimeLimits,
                    ),
                  )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set Time Limit Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SetTimeLimitSheet extends StatefulWidget {
  const _SetTimeLimitSheet({
    required this.apps,
    required this.plugin,
  });

  final List<Map<String, dynamic>> apps;
  final ZoAppBlocker plugin;

  @override
  State<_SetTimeLimitSheet> createState() => _SetTimeLimitSheetState();
}

class _SetTimeLimitSheetState extends State<_SetTimeLimitSheet> {
  Map<String, dynamic>? _selectedApp;
  int _limitMinutes = 30;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Set Daily Time Limit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // App picker
              const Text('1. Pick an app',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.apps.length,
                  itemBuilder: (context, index) {
                    final app = widget.apps[index];
                    final selected =
                        _selectedApp?['packageName'] == app['packageName'];
                    return ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      leading:
                          _AppIcon(packageName: app['packageName'] ?? '', size: 36),
                      title: Text(app['appName'] ?? ''),
                      subtitle: Text(
                        app['packageName'] ?? '',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => setState(() => _selectedApp = app),
                    );
                  },
                ),
              ),

              if (_selectedApp != null) ...[
                const Divider(height: 24),
                Text(
                  '2. Daily limit for ${_selectedApp!['appName']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _limitMinutes.toDouble(),
                        min: 1,
                        max: 180,
                        divisions: 179,
                        label: '$_limitMinutes min',
                        onChanged: (v) =>
                            setState(() => _limitMinutes = v.round()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '$_limitMinutes min',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Quick-pick chips
                Wrap(
                  spacing: 8,
                  children: [15, 30, 45, 60, 90, 120].map((m) {
                    return ChoiceChip(
                      label: Text('${m}m'),
                      selected: _limitMinutes == m,
                      onSelected: (_) => setState(() => _limitMinutes = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await widget.plugin.setAppTimeLimit(
                            packageName:
                                _selectedApp!['packageName'] as String,
                            dailyLimitMinutes: _limitMinutes,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Set ${_limitMinutes}m daily limit for '
                                  '${_selectedApp!['appName']}',
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Time Limit'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time Limit Tile (shows progress bar + actions)
// ─────────────────────────────────────────────────────────────────────────────

class _TimeLimitTile extends StatelessWidget {
  const _TimeLimitTile({
    required this.limit,
    required this.plugin,
    required this.onChanged,
  });

  final AppTimeLimit limit;
  final ZoAppBlocker plugin;
  final VoidCallback onChanged;

  String _fmtSeconds(int s) {
    if (s >= 60) return '${s ~/ 60}m ${s % 60}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final color = limit.isExhausted
        ? Colors.red
        : limit.usageRatio > 0.75
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AppIcon(packageName: limit.packageName, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        limit.packageName.split('.').last,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        limit.packageName,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (limit.isExhausted)
                  const Chip(
                    label: Text('BLOCKED',
                        style: TextStyle(
                            fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: limit.usageRatio,
                minHeight: 8,
                color: color,
                backgroundColor: color.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  limit.isExhausted
                      ? 'Budget exhausted'
                      : '${_fmtSeconds(limit.remainingSeconds)} remaining',
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_fmtSeconds(limit.usedSeconds)} / ${_fmtSeconds(limit.dailyLimitSeconds)}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await plugin.resetAppUsage(limit.packageName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Usage reset to 0')),
                      );
                      onChanged();
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await plugin.removeAppTimeLimit(limit.packageName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Time limit removed')),
                      );
                      onChanged();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.packageName, this.size = 40});

  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ZoAppBlocker.instance.getAppIcon(packageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, width: size, height: size);
        }
        return Icon(Icons.android, size: size, color: Colors.grey);
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
