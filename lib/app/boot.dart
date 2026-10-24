import 'package:flutter/material.dart';

import '../core/contracts/contracts.dart';
import '../features/action_guide/action_guide.dart';
import '../features/capture_ocr/capture_ocr.dart';
import '../features/classification/classification.dart';
import '../features/gemma_vision/gemma_vision.dart';
import '../features/screens/app_shell_screen.dart';
import '../features/vault/vault.dart';
import 'app_controller.dart';
import 'default_services.dart';
import 'theme.dart';

/// Runtime dependency container composed at startup (`lib/app/boot.dart`).
///
/// Wires Developer 1 (Offline OCR & Capture), Developer 2 (Classification &
/// Date Extraction), Developer 3 (SQLite Vault, Grounded Q&A & Reminders),
/// Developer 4 (App Controller & Screens), and Qwen v0.2 Action Guide.
class LifeVaultDependencies {
  const LifeVaultDependencies({
    required this.ocrService,
    required this.extractionService,
    required this.vaultRepository,
    required this.questionService,
    required this.reminderService,
    this.actionGuideService,
    this.gemmaVisionService,
    this.visionExtractionService,
    this.captureDelegate,
    this.nowProvider,
    this.isPersistentStorage = false,
  });

  final OfflineOcrService ocrService;
  final DocumentExtractionService extractionService;
  final VaultRepository vaultRepository;
  final QuestionService questionService;
  final ReminderService reminderService;
  final ActionGuideService? actionGuideService;
  final GemmaVisionExtractionService? gemmaVisionService;
  final VisionDocumentExtractionService? visionExtractionService;
  final ImageCaptureDelegate? captureDelegate;
  final DateTime Function()? nowProvider;
  final bool isPersistentStorage;

  /// Synchronous default composition for isolated widget tests (`LifeVaultApp()`).
  /// Uses D1's [OfflineOcrServiceImpl] and D2's pure-Dart
  /// [LifeVaultDocumentExtractionService] with an in-memory vault repository.
  factory LifeVaultDependencies.createDefault() {
    final repository = InMemoryVaultRepository();
    return LifeVaultDependencies(
      ocrService: OfflineOcrServiceImpl(),
      extractionService: const LifeVaultDocumentExtractionService(),
      vaultRepository: repository,
      questionService: GroundedVaultQuestionService(repository),
      reminderService: const NoOpReminderService(),
      actionGuideService: HybridActionGuideService(),
      captureDelegate: CaptureServiceImageDelegate(),
      isPersistentStorage: false,
    );
  }

  /// Production asynchronous composition connecting D1 native Tesseract OCR,
  /// D2 keyword/date extraction, D3 SQLite + app-private file storage +
  /// Android local notification scheduling, and Hybrid Qwen Action Guide.
  static Future<LifeVaultDependencies> createProduction() async {
    try {
      final sqliteRepo = await VaultRepositoryImpl.create();
      final adapterRepo = ProductionVaultRepositoryAdapter(sqliteRepo);
      final reminderService = ReminderServiceImpl(repo: sqliteRepo);
      await reminderService.initialize();

      return LifeVaultDependencies(
        ocrService: OfflineOcrServiceImpl(),
        extractionService: const LifeVaultDocumentExtractionService(),
        vaultRepository: adapterRepo,
        questionService: GroundedVaultQuestionService(adapterRepo),
        reminderService: reminderService,
        actionGuideService: HybridActionGuideService(),
        captureDelegate: CaptureServiceImageDelegate(),
        isPersistentStorage: true,
      );
    } on Object {
      // Safe fallback when running on desktop/CI without Android SQLite paths.
      return LifeVaultDependencies.createDefault();
    }
  }
}

/// Root application widget for LifeVault v0.1 / v0.2.
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
        actionGuideService: deps.actionGuideService,
        gemmaVisionService: deps.gemmaVisionService,
        visionExtractionService: deps.visionExtractionService,
        captureDelegate: deps.captureDelegate ?? CaptureServiceImageDelegate(),
        nowProvider: deps.nowProvider,
        isPersistentStorage: deps.isPersistentStorage,
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
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'LifeVault',
          debugShowCheckedModeBanner: false,
          theme: LifeVaultTheme.light(),
          darkTheme: LifeVaultTheme.dark(),
          themeMode: _controller.themeMode,
          home: AppShellScreen(controller: _controller),
        );
      },
    );
  }
}
