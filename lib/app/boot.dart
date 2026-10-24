import 'package:flutter/material.dart';

import '../core/contracts/contracts.dart';
import '../features/screens/app_shell_screen.dart';
import 'app_controller.dart';
import 'default_services.dart';
import 'theme.dart';

/// Runtime dependency container composed at startup (`lib/app/boot.dart`).
class LifeVaultDependencies {
  const LifeVaultDependencies({
    required this.ocrService,
    required this.extractionService,
    required this.vaultRepository,
    required this.questionService,
    required this.reminderService,
    this.captureDelegate,
    this.nowProvider,
  });

  final OfflineOcrService ocrService;
  final DocumentExtractionService extractionService;
  final VaultRepository vaultRepository;
  final QuestionService questionService;
  final ReminderService reminderService;
  final ImageCaptureDelegate? captureDelegate;
  final DateTime Function()? nowProvider;

  factory LifeVaultDependencies.createDefault() {
    final repository = InMemoryVaultRepository();
    return LifeVaultDependencies(
      ocrService: const MethodChannelOfflineOcrService(),
      extractionService: const FallbackDocumentExtractionService(),
      vaultRepository: repository,
      questionService: GroundedVaultQuestionService(repository),
      reminderService: const NoOpReminderService(),
      captureDelegate: DeviceImageCaptureDelegate(),
    );
  }
}

/// Root application widget for LifeVault v0.1.
class LifeVaultApp extends StatefulWidget {
  const LifeVaultApp({
    super.key,
    this.dependencies,
    this.controller,
  });

  final LifeVaultDependencies? dependencies;
  final LifeVaultController? controller;

  @override
  State<LifeVaultApp> createState() => _LifeVaultAppState();
}

class _LifeVaultAppState extends State<LifeVaultApp> {
  late final LifeVaultController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final deps = widget.dependencies ?? LifeVaultDependencies.createDefault();
      _controller = LifeVaultController(
        ocrService: deps.ocrService,
        extractionService: deps.extractionService,
        vaultRepository: deps.vaultRepository,
        questionService: deps.questionService,
        reminderService: deps.reminderService,
        captureDelegate: deps.captureDelegate ?? DeviceImageCaptureDelegate(),
        nowProvider: deps.nowProvider,
      );
      _ownsController = true;
    }
    _controller.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeVault',
      debugShowCheckedModeBanner: false,
      theme: LifeVaultTheme.light(),
      home: AppShellScreen(controller: _controller),
    );
  }
}
