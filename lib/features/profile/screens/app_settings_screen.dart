// lib/features/profile/screens/app_settings_screen.dart
// Group 8 changes:
//  P5-1: _saveSettings() is silent — no snackbar spam on rapid toggling.
//  P5-2: Promotional toggle removed — this is a B2B delivery tool, not a
//        consumer app. There are no promotional notifications.
//  P5-3: "Clear Cache" now actually clears data: offline location queue +
//        recent customer searches. Auth data survives.
//  P5-4: "Privacy Policy" and "Terms of Service" tiles removed entirely.
//        They showed "Coming soon" snackbars — not acceptable in production.
//  BONUS: activeColor → activeThumbColor (fixes the deprecated API warning).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/storage_service.dart';
import '../../go_to/providers/go_to_provider.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _orderNotifications = true;
  bool _deliveryUpdates = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ─── LOAD ─────────────────────────────────────────────────────────────────
  // Uses StorageService.getNotificationSettings() which reads from the
  // cached prefs instance — synchronous, no async overhead.

  void _loadSettings() {
    final s = StorageService.getNotificationSettings();
    setState(() {
      _notificationsEnabled = s.enabled;
      _orderNotifications = s.orderNotifs;
      _deliveryUpdates = s.deliveryUpdates;
      _soundEnabled = s.sound;
      _vibrationEnabled = s.vibration;
      _isLoading = false;
    });
  }

  // ─── SAVE (P5-1: silent) ──────────────────────────────────────────────────
  // Saves are fire-and-forget. The toggle's visual state IS the feedback.
  // No snackbar — rapid toggling previously stacked multiple banners.

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        StorageService.keyNotificationsEnabled, _notificationsEnabled);
    await prefs.setBool(
        StorageService.keyOrderNotifications, _orderNotifications);
    await prefs.setBool(
        StorageService.keyDeliveryUpdates, _deliveryUpdates);
    await prefs.setBool(StorageService.keySoundEnabled, _soundEnabled);
    await prefs.setBool(
        StorageService.keyVibrationEnabled, _vibrationEnabled);
    // No snackbar — intentional (P5-1).
  }

  // ─── CLEAR CACHE (P5-3: real implementation) ──────────────────────────────

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Cache',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will clear the offline location queue and recent customer '
          'searches. Your account, orders, and settings will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _clearCache();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    // 1. Clear offline location update queue from SharedPreferences.
    await StorageService.clearLocationQueue();

    // 2. Clear recent customer searches from SharedPreferences.
    await StorageService.clearRecentSearches();

    // 3. Sync the in-memory GoToProvider list so the Go To screen
    //    immediately reflects the cleared state without a restart.
    if (mounted) {
      await context.read<GoToProvider>().clearRecentSearches();
    }

    // 4. Show success feedback — only AFTER the work is done.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ─── ABOUT ────────────────────────────────────────────────────────────────

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ice Cream Delivery Partner',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('Version: 1.0.0'),
            const SizedBox(height: 16),
            const Text(
              'Designed for the Ice Cream Inventory Management Team',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 All rights reserved',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.015 * 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDBE0E6)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Notifications ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'NOTIFICATIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF617589),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildSwitchTile(
                    icon: Icons.notifications,
                    title: 'Enable Notifications',
                    subtitle: 'Receive app notifications',
                    value: _notificationsEnabled,
                    onChanged: (v) {
                      setState(() => _notificationsEnabled = v);
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildSwitchTile(
                    icon: Icons.assignment,
                    title: 'Order Notifications',
                    subtitle: 'New order assignments',
                    value: _orderNotifications,
                    onChanged: _notificationsEnabled
                        ? (v) {
                            setState(() => _orderNotifications = v);
                            _saveSettings();
                          }
                        : null,
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildSwitchTile(
                    icon: Icons.local_shipping,
                    title: 'Delivery Updates',
                    subtitle: 'Status and tracking alerts',
                    value: _deliveryUpdates,
                    onChanged: _notificationsEnabled
                        ? (v) {
                            setState(() => _deliveryUpdates = v);
                            _saveSettings();
                          }
                        : null,
                  ),
                  // P5-2: Promotional Notifications tile removed.
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Sound & Vibration ─────────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'SOUND & VIBRATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF617589),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildSwitchTile(
                    icon: Icons.volume_up,
                    title: 'Sound',
                    subtitle: 'Play notification sounds',
                    value: _soundEnabled,
                    onChanged: (v) {
                      setState(() => _soundEnabled = v);
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildSwitchTile(
                    icon: Icons.vibration,
                    title: 'Vibration',
                    subtitle: 'Vibrate on notifications',
                    value: _vibrationEnabled,
                    onChanged: (v) {
                      setState(() => _vibrationEnabled = v);
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── App Data ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'APP DATA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF617589),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildActionTile(
                    icon: Icons.cleaning_services,
                    title: 'Clear Cache',
                    subtitle: 'Clears offline queue and recent searches',
                    onTap: _showClearCacheDialog,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── About ─────────────────────────────────────────────────────
            // P5-4: Privacy Policy and Terms of Service tiles removed.
            //       They showed "Coming soon" snackbars — not production ready.
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'ABOUT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF617589),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildActionTile(
                    icon: Icons.info,
                    title: 'About App',
                    subtitle: 'Version and credits',
                    onTap: _showAboutDialog,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── TILE BUILDERS ────────────────────────────────────────────────────────

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    final isDisabled = onChanged == null;
    return SwitchListTile(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.shade200
              : const Color(0xFF2B8CEE).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.grey : const Color(0xFF2B8CEE),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDisabled ? Colors.grey : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDisabled ? Colors.grey : const Color(0xFF617589),
        ),
      ),
      value: value,
      onChanged: onChanged,
      // Replaced deprecated activeColor with activeThumbColor (P5-2 bonus fix).
      activeThumbColor: const Color(0xFF2B8CEE),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF2B8CEE).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2B8CEE), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Color(0xFF617589)),
      ),
      trailing:
          const Icon(Icons.chevron_right, color: Color(0xFF617589)),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}