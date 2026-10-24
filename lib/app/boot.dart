import 'package:flutter/material.dart';

import '../core/contracts/contracts.dart';
import 'theme.dart';

/// Runtime dependency container composed at startup (`lib/app/boot.dart`).
class LifeVaultDependencies {
  const LifeVaultDependencies({
    required this.ocrService,
    required this.extractionService,
    required this.vaultRepository,
    required this.questionService,
    required this.reminderService,
  });

  final OfflineOcrService ocrService;
  final DocumentExtractionService extractionService;
  final VaultRepository vaultRepository;
  final QuestionService questionService;
  final ReminderService reminderService;
}

/// Root application widget for LifeVault v0.1.
class LifeVaultApp extends StatelessWidget {
  const LifeVaultApp({super.key, this.dependencies});

  final LifeVaultDependencies? dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeVault',
      debugShowCheckedModeBanner: false,
      theme: LifeVaultTheme.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('LifeVault')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Photograph it once. Find it instantly. '
              'Never miss an important date.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
