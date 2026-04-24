// lib/features/go_to/screens/customer_detail_screen.dart
// Refactored for strong CTA emphasis, clean spacing, and smooth transitions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_model.dart';

class CustomerDetailScreen extends StatelessWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  Future<void> _makeCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSnack(context, 'No phone number available');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _navigate(BuildContext context) async {
    if (customer.location == null || !customer.location!.isValid) {
      _showSnack(context, 'Location not available for this customer');
      return;
    }
    final lat = customer.location!.latitude;
    final lng = customer.location!.longitude;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack(context, '$label copied to clipboard');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
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
          'Customer Details',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(customer: customer),
            const SizedBox(height: 16),
            _ContactSection(
              customer: customer,
              onCall: (phone) => _makeCall(context, phone),
              onCopy: (text, label) => _copyToClipboard(context, text, label),
            ),
            const SizedBox(height: 24),
            _AddressSection(
              customer: customer,
              onCopy: (text) => _copyToClipboard(context, text, 'Address'),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _BottomActions(
        onCall: () => _makeCall(context, customer.primaryContact),
        onNavigate: () => _navigate(context),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final CustomerModel customer;

  const _HeaderCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE0E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'customer_avatar_${customer.id}',
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.storefront,
                color: Color(0xFF2B8CEE),
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  customer.shopName,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF617589),
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact ────────────────────────────────────────────────────────────────

class _ContactSection extends StatelessWidget {
  final CustomerModel customer;
  final ValueChanged<String> onCall;
  final void Function(String text, String label) onCopy;

  const _ContactSection({
    required this.customer,
    required this.onCall,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (customer.contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('CONTACT INFORMATION'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDBE0E6)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < customer.contacts.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, indent: 72, color: Color(0xFFDBE0E6)),
                _ContactTile(
                  label: 'Phone ${i + 1}',
                  value: customer.contacts[i],
                  onCall: () => onCall(customer.contacts[i]),
                  onCopy: () => onCopy(customer.contacts[i], 'Phone number'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCall;
  final VoidCallback onCopy;

  const _ContactTile({
    required this.label,
    required this.value,
    required this.onCall,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone,
                    color: Color(0xFF2B8CEE), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF617589),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111418),
                      ),
                    ),
                  ],
                ),
              ),
              _CircleIconButton(
                icon: Icons.copy,
                onTap: onCopy,
                color: const Color(0xFF617589),
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.call,
                onTap: onCall,
                color: const Color(0xFF2B8CEE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Address ────────────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  final CustomerModel customer;
  final ValueChanged<String> onCopy;

  const _AddressSection({required this.customer, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('ADDRESS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDBE0E6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shop Address',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF617589),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      customer.shopAddress,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (customer.location?.isValid ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${customer.location!.latitude?.toStringAsFixed(5)}, '
                        '${customer.location!.longitude?.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF617589),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _CircleIconButton(
                icon: Icons.copy,
                onTap: () => onCopy(customer.shopAddress),
                color: const Color(0xFF617589),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Actions ─────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onNavigate;

  const _BottomActions({required this.onCall, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFDBE0E6))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.directions, size: 22),
                label: const Text(
                  'Navigate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B8CEE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call, size: 20),
                label: const Text(
                  'Call Customer',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B8CEE),
                  side: const BorderSide(color: Color(0xFF2B8CEE)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF617589),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}