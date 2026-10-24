import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import 'welcome_screen.dart';

/// Settings & Privacy screen (`/settings` P1 spec).
///
/// Gives users transparent control over privacy, local processing status,
/// vault storage statistics, reminder preferences, and appearance theme mode.
/// Never advertises unverified encryption, cloud backup, or biometric locks.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  Future<void> _openOnboarding(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => WelcomeScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDocs = controller.allDocuments.length;
    final verifiedDeadlines = controller.verifiedDeadlines.length;
    final needsReview = controller.needsReviewDocuments.length;
    final currentTheme = controller.themeMode;
    final defaultOffsets = controller.defaultReminderOffsets;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Settings & Privacy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transparent control over on-device processing, storage, and reminder preferences.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: LifeVaultColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const Key('settings_open_welcome_button'),
              onPressed: () => _openOnboarding(context),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Welcome Guide'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSectionHeader(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & Local Processing',
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  'Network Access Permission',
                  'Removed from Release Manifest (Zero External Requests)',
                  isPositive: true,
                ),
                _buildStatusRow(
                  'OCR Engine',
                  'On-Device Tesseract 5 (Bundled eng.traineddata)',
                  isPositive: true,
                ),
                _buildStatusRow(
                  'Question Answering Mode',
                  'Deterministic Grounded SQLite Lookup (No Remote AI)',
                  isPositive: true,
                ),
                _buildStatusRow(
                  'Remote Processing / Cloud Telemetry',
                  'Disabled (100% Local)',
                  isPositive: true,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const Key('settings_verify_services_button'),
                      onPressed: controller.checkLocalServices,
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: const Text('Verify Local Readiness'),
                    ),
                    if (controller.scanErrorMessage != null ||
                        controller.statusBannerMessage != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          controller.clearStatusBanner();
                          controller.clearSelectedScanFile();
                        },
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Clear Local Processing Notices'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSectionHeader(
                  context,
                  icon: Icons.storage_outlined,
                  title: 'Vault Storage & Honest Security Scope',
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  'Storage Engine',
                  controller.isPersistentStorage
                      ? 'App-Private SQLite + Private File Directory'
                      : 'In-Memory Local Vault Session',
                  isPositive: true,
                ),
                _buildStatusRow(
                  'Stored Documents',
                  '$totalDocs document(s) ($needsReview awaiting review)',
                ),
                _buildStatusRow(
                  'Verified Deadlines',
                  '$verifiedDeadlines confirmed deadline(s)',
                ),
                _buildStatusRow(
                  'Android Auto Backup',
                  'Disabled (android:allowBackup="false")',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LifeVaultColors.infoBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Transparency Notice (v0.1 Lite): Documents and metadata stay in app-private storage '
                    'with zero network permissions. At-rest file encryption and cloud backups are not enabled '
                    'in v0.1 — uninstalling the app or clearing app storage permanently removes local vault records.',
                    style: TextStyle(
                      fontSize: 13,
                      color: LifeVaultColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSectionHeader(
                  context,
                  icon: Icons.notifications_none_outlined,
                  title: 'Reminder Preferences',
                ),
                const SizedBox(height: 10),
                Text(
                  'Default advance-warning schedule for new confirmed deadlines:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('30, 7 & 1 days before'),
                      selected: defaultOffsets.length == 3,
                      onSelected: (_) => controller.setDefaultReminderOffsets(
                        const <int>[30, 7, 1],
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('15 & 7 days before'),
                      selected: defaultOffsets.length == 2 &&
                          defaultOffsets.contains(15),
                      onSelected: (_) => controller.setDefaultReminderOffsets(
                        const <int>[15, 7],
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('7 days before'),
                      selected: defaultOffsets.length == 1 &&
                          defaultOffsets.first == 7,
                      onSelected: (_) => controller.setDefaultReminderOffsets(
                        const <int>[7],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSectionHeader(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      key: const Key('theme_mode_light'),
                      label: const Text('Light Theme'),
                      selected: currentTheme == ThemeMode.light,
                      onSelected: (_) =>
                          controller.setThemeMode(ThemeMode.light),
                    ),
                    ChoiceChip(
                      key: const Key('theme_mode_system'),
                      label: const Text('System Theme'),
                      selected: currentTheme == ThemeMode.system,
                      onSelected: (_) =>
                          controller.setThemeMode(ThemeMode.system),
                    ),
                    ChoiceChip(
                      key: const Key('theme_mode_dark'),
                      label: const Text('Dark Theme'),
                      selected: currentTheme == ThemeMode.dark,
                      onSelected: (_) =>
                          controller.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, color: LifeVaultColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    bool isPositive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: LifeVaultColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                if (isPositive) ...<Widget>[
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: LifeVaultColors.success,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
