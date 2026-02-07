// lib/features/profile/screens/app_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _orderNotifications = true;
  bool _deliveryUpdates = true;
  bool _promotionalNotifications = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _orderNotifications = prefs.getBool('order_notifications') ?? true;
      _deliveryUpdates = prefs.getBool('delivery_updates') ?? true;
      _promotionalNotifications = prefs.getBool('promotional_notifications') ?? false;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('order_notifications', _orderNotifications);
    await prefs.setBool('delivery_updates', _deliveryUpdates);
    await prefs.setBool('promotional_notifications', _promotionalNotifications);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ice Cream Delivery Partner',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear temporary app data. Your account information will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
          child: Container(
            height: 1,
            color: const Color(0xFFDBE0E6),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Notifications Section
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
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
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
                        ? (value) {
                            setState(() => _orderNotifications = value);
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
                        ? (value) {
                            setState(() => _deliveryUpdates = value);
                            _saveSettings();
                          }
                        : null,
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildSwitchTile(
                    icon: Icons.campaign,
                    title: 'Promotional',
                    subtitle: 'Offers and announcements',
                    value: _promotionalNotifications,
                    onChanged: _notificationsEnabled
                        ? (value) {
                            setState(() => _promotionalNotifications = value);
                            _saveSettings();
                          }
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Sound & Vibration Section
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
                    onChanged: (value) {
                      setState(() => _soundEnabled = value);
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildSwitchTile(
                    icon: Icons.vibration,
                    title: 'Vibration',
                    subtitle: 'Vibrate on notifications',
                    value: _vibrationEnabled,
                    onChanged: (value) {
                      setState(() => _vibrationEnabled = value);
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // App Data Section
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
                    subtitle: 'Free up storage space',
                    onTap: _showClearCacheDialog,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // About Section
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
                  const Divider(height: 1, indent: 72),
                  _buildActionTile(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    subtitle: 'View privacy policy',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy Policy - Coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _buildActionTile(
                    icon: Icons.description,
                    title: 'Terms of Service',
                    subtitle: 'View terms and conditions',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terms of Service - Coming soon'),
                        ),
                      );
                    },
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
      activeColor: const Color(0xFF2B8CEE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        child: Icon(
          icon,
          color: const Color(0xFF2B8CEE),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF617589),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF617589),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}