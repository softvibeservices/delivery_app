// lib/features/profile/screens/app_settings_screen.dart
// Refactored: Silent saves, real cache clearing, grouped switches,
// no deprecated API usage, skeleton on init.

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
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _orderNotifications = true;
  bool _deliveryUpdates = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

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
    // Intentionally silent — no snackbar (P5-1).
  }

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
    await StorageService.clearLocationQueue();
    await StorageService.clearRecentSearches();

    if (mounted) {
      await context.read<GoToProvider>().clearRecentSearches();
    }

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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About App'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ice Cream Delivery Partner',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 16),
            Text(
              'Designed for the Ice Cream Inventory Management Team',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 16),
            Text(
              '© 2025 All rights reserved',
              style: TextStyle(fontSize: 12, color: Color(0xFF617589)),
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

  @override
  Widget build(BuildContext context) {
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
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFDBE0E6)),
        ),
      ),
      body: _isLoading
          ? const _SettingsSkeleton()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    title: 'NOTIFICATIONS',
                    children: [
                      _SwitchTile(
                        icon: Icons.notifications_outlined,
                        title: 'Enable Notifications',
                        subtitle: 'Receive app notifications',
                        value: _notificationsEnabled,
                        onChanged: (v) {
                          setState(() => _notificationsEnabled = v);
                          _saveSettings();
                        },
                      ),
                      const _Divider(),
                      _SwitchTile(
                        icon: Icons.assignment_outlined,
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
                      const _Divider(),
                      _SwitchTile(
                        icon: Icons.local_shipping_outlined,
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    title: 'SOUND & VIBRATION',
                    children: [
                      _SwitchTile(
                        icon: Icons.volume_up_outlined,
                        title: 'Sound',
                        subtitle: 'Play notification sounds',
                        value: _soundEnabled,
                        onChanged: (v) {
                          setState(() => _soundEnabled = v);
                          _saveSettings();
                        },
                      ),
                      const _Divider(),
                      _SwitchTile(
                        icon: Icons.vibration_outlined,
                        title: 'Vibration',
                        subtitle: 'Vibrate on notifications',
                        value: _vibrationEnabled,
                        onChanged: (v) {
                          setState(() => _vibrationEnabled = v);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    title: 'APP DATA',
                    children: [
                      _ActionTile(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Clear Cache',
                        subtitle: 'Offline queue and recent searches',
                        onTap: _showClearCacheDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsGroup(
                    title: 'ABOUT',
                    children: [
                      _ActionTile(
                        icon: Icons.info_outline,
                        title: 'About App',
                        subtitle: 'Version and credits',
                        onTap: _showAboutDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── WIDGETS ────────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF617589),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return SwitchListTile(
      secondary: _IconBox(icon: icon, disabled: disabled),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: disabled ? Colors.grey : const Color(0xFF111418),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: disabled ? Colors.grey.shade400 : const Color(0xFF617589),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF2B8CEE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const _IconBox(icon: Icons.cleaning_services_outlined),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Color(0xFF617589)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF617589)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.disabled = false});

  final IconData icon;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: disabled
            ? Colors.grey.shade200
            : const Color(0xFF2B8CEE).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: disabled ? Colors.grey : const Color(0xFF2B8CEE),
        size: 20,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 72, color: Color(0xFFDBE0E6));
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SkeletonCard(height: 220),
          const SizedBox(height: 12),
          _SkeletonCard(height: 140),
          const SizedBox(height: 12),
          _SkeletonCard(height: 80),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}