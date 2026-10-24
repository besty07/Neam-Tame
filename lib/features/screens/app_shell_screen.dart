import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'ask_screen.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'vault_screen.dart';

/// Four-tab portrait navigation shell for LifeVault v0.1:
/// Home / Scan / Vault / Ask (Section 4).
class AppShellScreen extends StatelessWidget {
  const AppShellScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  static const List<String> _tabTitles = <String>[
    'LifeVault',
    'Scan Document',
    'Document Vault',
    'Ask LifeVault',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tabIndex = controller.activeTabIndex;
        final bannerMessage = controller.statusBannerMessage;

        Widget bodyContent;
        switch (tabIndex) {
          case 1:
            bodyContent = ScanScreen(controller: controller);
          case 2:
            bodyContent = VaultScreen(controller: controller);
          case 3:
            bodyContent = AskScreen(controller: controller);
          case 0:
          default:
            bodyContent = HomeScreen(controller: controller);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_tabTitles[tabIndex]),
            actions: <Widget>[
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(Icons.airplanemode_active, size: 16),
                  label: Text('Offline'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              if (bannerMessage != null)
                MaterialBanner(
                  key: const Key('app_status_banner'),
                  content: Text(bannerMessage),
                  leading: const Icon(Icons.info_outline),
                  actions: <Widget>[
                    TextButton(
                      key: const Key('dismiss_status_banner_button'),
                      onPressed: controller.clearStatusBanner,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(child: bodyContent),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            key: const Key('app_bottom_navigation'),
            selectedIndex: tabIndex,
            onDestinationSelected: controller.setActiveTab,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                key: Key('nav_tab_home'),
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                key: Key('nav_tab_scan'),
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner),
                label: 'Scan',
              ),
              NavigationDestination(
                key: Key('nav_tab_vault'),
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'Vault',
              ),
              NavigationDestination(
                key: Key('nav_tab_ask'),
                icon: Icon(Icons.question_answer_outlined),
                selectedIcon: Icon(Icons.question_answer),
                label: 'Ask',
              ),
            ],
          ),
        );
      },
    );
  }
}
