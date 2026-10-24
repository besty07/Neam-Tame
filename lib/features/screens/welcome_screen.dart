import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';

/// Welcome & Local Readiness screen (Onboarding / P1 spec).
///
/// Introduces LifeVault's privacy-first architecture, explains actual local
/// storage behavior without unverified security claims, and verifies local
/// OCR and vault service readiness.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to LifeVault'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final checkSummary = controller.lastServiceCheckSummary;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: LifeVaultColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  color: LifeVaultColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Welcome to LifeVault',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Your family's documents, deadlines and answers.",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                LifeVaultColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              FilledButton.icon(
                                key: const Key('welcome_get_started_button'),
                                onPressed: () {
                                  controller.setActiveTab(1);
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(
                                  Icons.document_scanner_outlined,
                                ),
                                label: const Text('Get Started'),
                              ),
                              OutlinedButton.icon(
                                key: const Key('welcome_check_services_button'),
                                onPressed: controller.checkLocalServices,
                                icon: const Icon(Icons.verified_outlined),
                                label: const Text('Check Local Services'),
                              ),
                              TextButton.icon(
                                key: const Key('welcome_open_dashboard_button'),
                                onPressed: () {
                                  controller.setActiveTab(0);
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.dashboard_outlined),
                                label: const Text('Open Dashboard'),
                              ),
                            ],
                          ),
                          if (checkSummary != null) ...<Widget>[
                            const SizedBox(height: 14),
                            Container(
                              key: const Key('welcome_readiness_banner'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: LifeVaultColors.successBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: LifeVaultColors.success,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: LifeVaultColors.success,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      checkSummary,
                                      style: const TextStyle(
                                        color: LifeVaultColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildSectionTile(
                            context,
                            icon: Icons.camera_enhance_outlined,
                            title:
                                'Photograph it once. Find it instantly. Never miss an important date.',
                            description:
                                'Capture insurance policies, appliance warranties, utility bills, '
                                'medical papers, and vehicle records. Review extracted dates before '
                                'they become trusted household reminders.',
                          ),
                          const SizedBox(height: 12),
                          _buildSectionTile(
                            context,
                            icon: Icons.lock_person_outlined,
                            title: 'Your files stay with you',
                            description:
                                'All OCR text recognition (Tesseract 5 English model), classification, '
                                'and SQLite storage run locally on your device with zero network '
                                'transmission and Android Auto Backup disabled. Note: v0.1 uses '
                                'app-private storage and does not claim at-rest file encryption; '
                                'uninstalling the app deletes local vault files.',
                          ),
                          const SizedBox(height: 12),
                          _buildSectionTile(
                            context,
                            icon: Icons.fact_check_outlined,
                            title: 'Prepare your vault',
                            description:
                                'No account creation or cloud sign-in is required. Verify local '
                                'storage and offline OCR availability above at any time.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LifeVaultColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LifeVaultColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: LifeVaultColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LifeVaultColors.textSecondary,
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
