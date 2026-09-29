import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';

import '../screens/paywall_screen.dart';
import '../services/admob_service.dart';
import '../services/blocker_service.dart';
import '../services/companion_service.dart';
import '../services/revenuecat_service.dart';
import '../services/time_bank.dart';
import 'pippy_avatar_widget.dart';

// ── App Icon Widget ──────────────────────────────────────────────────────────

/// Lazily loads and caches an app icon from the native layer with **LRU cache**.
/// Maintains an in-memory cache of up to 50 icons to reduce native calls.
class AppIconWidget extends StatefulWidget {
  final String packageName;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final Color fallbackBgColor;

  const AppIconWidget({
    super.key,
    required this.packageName,
    this.size = 44,
    this.fallbackIcon = Icons.android_rounded,
    this.fallbackIconColor = const Color(0xFF555555),
    this.fallbackBgColor = const Color(0xFFF0F0F2),
  });

  @override
  State<AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends State<AppIconWidget> {
  /// LRU cache for app icons (shared across all instances).
  static final Map<String, Uint8List?> _iconCache = {};
  static final List<String> _cacheOrder = [];
  static const int _maxCacheSize = 50;

  Uint8List? _iconBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Check cache first
    if (_iconCache.containsKey(widget.packageName)) {
      if (mounted) {
        setState(() {
          _iconBytes = _iconCache[widget.packageName];
          _loading = false;
        });
      }
      // Update LRU order
      _cacheOrder.remove(widget.packageName);
      _cacheOrder.add(widget.packageName);
      return;
    }

    // Fetch from native layer
    final bytes = await BlockerService.instance.getAppIcon(widget.packageName);

    // Add to cache with LRU eviction
    if (_iconCache.length >= _maxCacheSize) {
      final oldest = _cacheOrder.removeAt(0);
      _iconCache.remove(oldest);
    }

    _iconCache[widget.packageName] = bytes;
    _cacheOrder.add(widget.packageName);

    if (mounted) {
      setState(() {
        _iconBytes = bytes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    if (_loading) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: widget.fallbackBgColor,
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        child: Center(
          child: SizedBox(
            width: size * 0.4,
            height: size * 0.4,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: widget.fallbackIconColor,
            ),
          ),
        ),
      );
    }

    if (_iconBytes != null && _iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.27),
        child: Image.memory(
          _iconBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (e, obj, st) => _fallback(size),
        ),
      );
    }

    return _fallback(size);
  }

  Widget _fallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.fallbackBgColor,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(
        widget.fallbackIcon,
        color: widget.fallbackIconColor,
        size: size * 0.5,
      ),
    );
  }
}

// ── Multi-Select App Selector Sheet ──────────────────────────────────────────

/// Bottom-sheet that lets the user select **multiple** apps to block.
///
/// App list is cached by [BlockerService] — subsequent opens are instant.
/// A ↺ refresh button lets the user force a fresh fetch if needed.
class AppSelectorSheet extends StatefulWidget {
  final Set<String> selectedPackageNames;
  final Function(List<String> packageNames, Map<String, String> displayNames)
  onAppsSelected;

  const AppSelectorSheet({
    super.key,
    required this.selectedPackageNames,
    required this.onAppsSelected,
  });

  @override
  State<AppSelectorSheet> createState() => _AppSelectorSheetState();
}

class _AppSelectorSheetState extends State<AppSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customPackageController =
      TextEditingController();

  List<AppInfo> _installedApps = [];
  bool _loadingApps = true;
  bool _refreshing = false;
  String _searchQuery = '';
  String? _errorMessage;
  String _selectedCategory = 'All';

  static const _categories = [
    'All',
    'Social',
    'Video',
    'Games',
    'Chat',
    'Browser',
  ];

  /// Local mutable copy of selected packages (pkg → display name).
  late Map<String, String> _selectedApps;

  @override
  void initState() {
    super.initState();
    final timeBank = TimeBankService.instance;
    _selectedApps = {};
    for (final pkg in widget.selectedPackageNames) {
      _selectedApps[pkg] = timeBank.displayNameFor(pkg);
    }
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customPackageController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps({bool forceRefresh = false}) async {
    setState(() {
      if (forceRefresh) {
        _refreshing = true;
      } else {
        _loadingApps = true;
      }
      _errorMessage = null;
    });

    try {
      final apps = await BlockerService.instance.getSelectableApps(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _loadingApps = false;
          _refreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingApps = false;
          _refreshing = false;
          _errorMessage = 'Could not load installed apps: $e';
        });
      }
    }
  }

  List<AppInfo> get _filteredApps {
    var apps = _installedApps;
    // Category filter
    if (_selectedCategory != 'All') {
      final cat = _selectedCategory;
      final presetPkgs = CommonApps.presets
          .where((p) => p.category == cat)
          .map((p) => p.packageName)
          .toSet();
      apps = apps.where((a) => presetPkgs.contains(a.packageName)).toList();
    }
    // Text search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      apps = apps.where((app) {
        return app.appName.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
      }).toList();
    }
    return apps;
  }

  void _toggleApp(String packageName, String appName) {
    final isPremium = RevenueCatService.instance.isPremium;
    final isSelectingNew = !_selectedApps.containsKey(packageName);

    if (!isPremium && isSelectingNew && _selectedApps.isNotEmpty) {
      _showUpgradePaywallDialog();
      return;
    }

    setState(() {
      if (_selectedApps.containsKey(packageName)) {
        _selectedApps.remove(packageName);
      } else {
        _selectedApps[packageName] = appName;
      }
    });
  }

  void _showUpgradePaywallDialog() {
    final companion = CompanionService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PippyAvatarWidget(
              size: 60,
              mood: PippyMood.celebrate,
              aura: companion.aura,
              accessory: companion.accessory,
              streakDays: companion.currentStreak,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unlock Unlimited Apps with Pro 🚀',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                fontFamily: 'Outfit',
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              companion.getAppLimitUpgradeDialogue(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Got it',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const PaywallScreen(source: 'app_limit_dialog'),
                ),
              );
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text(
              'See Pro Perks ⭐',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _applySelection() {
    final newSet = _selectedApps.keys.toSet();
    final originalSet = widget.selectedPackageNames;

    // If selection hasn't changed at all, simply dismiss sheet
    if (newSet.length == originalSet.length &&
        newSet.containsAll(originalSet)) {
      Navigator.of(context).pop();
      return;
    }

    _showSaveAppListAdConfirmation();
  }

  void _commitSelection() {
    widget.onAppsSelected(
      _selectedApps.keys.toList(),
      Map<String, String>.from(_selectedApps),
    );
  }

  /// AdMob Policy: Rewarded ads must be opt-in with explicit disclosure of reward
  /// before the ad begins. Saving the updated app list requires watching a rewarded ad.
  void _showSaveAppListAdConfirmation() {
    final companion = CompanionService.instance;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PippyAvatarWidget(
              size: 60,
              mood: PippyMood.walking,
              aura: companion.aura,
              accessory: companion.accessory,
              streakDays: companion.currentStreak,
            ),
            const SizedBox(height: 12),
            const Text(
              'Save Blocked Apps 🛡️',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                fontFamily: 'Outfit',
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You have selected ${_selectedApps.length} app${_selectedApps.length == 1 ? '' : 's'} to block.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFF047857),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watch a short video ad to apply and save your updated blocked apps list.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _playRewardedAdAndSave();
            },
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text(
              'Watch & Save ✨',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _playRewardedAdAndSave() {
    bool rewardEarned = false;
    AdMobService.instance.showAppListChangeRewardedAd(
      onRewardEarned: () {
        rewardEarned = true;
        _commitSelection();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blocked apps updated successfully! 🛡️'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onAdDismissed: () {
        if (!rewardEarned && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ad was closed early. Changes were not saved.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ad is loading or unavailable. Please check your connection and try again.',
              ),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  void _showCustomPackageDialog() {
    _customPackageController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Package Name'),
        content: TextField(
          controller: _customPackageController,
          decoration: const InputDecoration(
            hintText: 'e.g. com.example.app',
            labelText: 'Package Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = _customPackageController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _toggleApp(text, text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selCount = _selectedApps.length;
    final apps = _filteredApps;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handlebar ───────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.apps_rounded,
                  color: Color(0xFF666666),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Apps to Block',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selCount == 0
                            ? 'Tap apps to add them to the block list'
                            : '$selCount app${selCount == 1 ? '' : 's'} selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: selCount > 0
                              ? const Color(0xFF2D3748)
                              : Colors.grey,
                          fontWeight: selCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh button
                _refreshing
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh app list',
                        onPressed: () => _loadInstalledApps(forceRefresh: true),
                      ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Selected chips strip ─────────────────────────────────────
          if (_selectedApps.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedApps.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final pkg = _selectedApps.keys.elementAt(idx);
                  final name = _selectedApps[pkg]!;
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _toggleApp(pkg, name),
                    backgroundColor: const Color(0xFF2D3748),
                    labelStyle: const TextStyle(color: Colors.white),
                    deleteIconColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search ${_installedApps.length} installed apps...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Category filter chips ──────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isActive = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2D3748)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // App count / filter summary
          if (!_loadingApps && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _searchQuery.isEmpty
                        ? '${_installedApps.length} apps on this device'
                        : '${apps.length} result${apps.length == 1 ? '' : 's'} for "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF718096),
                    ),
                  ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),

          // ── App list ─────────────────────────────────────────────────
          Expanded(child: _buildAppList(apps)),

          // ── Bottom action bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _showCustomPackageDialog,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Custom Package'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: selCount > 0
                          ? const Color(0xFF2D3748)
                          : Colors.grey,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: selCount > 0 ? _applySelection : null,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(selCount > 0 ? 'Apply ($selCount)' : 'Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppList(List<AppInfo> apps) {
    if (_loadingApps) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
            SizedBox(height: 14),
            Text(
              'Loading apps...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadInstalledApps(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'No installed apps found on device'
                  : 'No apps matching "$_searchQuery"',
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = _selectedApps.containsKey(app.packageName);

        Widget iconWidget;
        if (app.icon != null && app.icon!.isNotEmpty) {
          iconWidget = ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              app.icon!,
              width: 52,
              height: 52,
              cacheWidth: 104,
              cacheHeight: 104,
              fit: BoxFit.cover,
              errorBuilder: (e, obj, st) => AppIconWidget(
                packageName: app.packageName,
                size: 52,
                fallbackBgColor: isSelected
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFF0F0F2),
                fallbackIconColor: isSelected
                    ? Colors.white
                    : const Color(0xFF555555),
              ),
            ),
          );
        } else {
          iconWidget = AppIconWidget(
            packageName: app.packageName,
            size: 52,
            fallbackBgColor: isSelected
                ? const Color(0xFF2D3748)
                : const Color(0xFFF0F0F2),
            fallbackIconColor: isSelected
                ? Colors.white
                : const Color(0xFF555555),
          );
        }

        final isPremium = RevenueCatService.instance.isPremium;
        final isLockedForFree =
            !isPremium && !isSelected && _selectedApps.isNotEmpty;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: SizedBox(width: 52, height: 52, child: iconWidget),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  app.appName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (isLockedForFree)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Text(
            app.packageName,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2D3748)
                  : (isLockedForFree
                        ? const Color(0xFFFEF3C7)
                        : Colors.transparent),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2D3748)
                    : (isLockedForFree
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFCBD5E0)),
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : (isLockedForFree
                      ? const Icon(
                          Icons.lock_rounded,
                          color: Color(0xFFD97706),
                          size: 14,
                        )
                      : null),
          ),
          onTap: () => _toggleApp(app.packageName, app.appName),
        );
      },
    );
  }
}
