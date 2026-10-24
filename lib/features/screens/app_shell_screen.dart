import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import 'ask_screen.dart';
import 'document_detail_screen.dart';
import 'family_assets_screen.dart';
import 'home_screen.dart';
import 'reminders_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'vault_screen.dart';
import 'welcome_screen.dart';

/// Responsive application shell for LifeVault:
/// - Desktop (`>= 1024px`): Fixed 250px left Sidebar + 70px sticky Topbar
/// - Mobile & Tablet (`< 1024px`): AppBar + sticky bottom NavigationBar
///   (Home / Scan / Vault / Ask) plus topbar actions for Reminders, Family &
///   Assets, Settings & Privacy, and Welcome Guide.
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
    'Reminders',
    'Family & Assets',
    'Settings & Privacy',
  ];

  Future<void> _openWelcomeScreen(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => WelcomeScreen(controller: controller),
      ),
    );
  }

  Widget _buildBodyForIndex(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return ScanScreen(controller: controller);
      case 2:
        return VaultScreen(controller: controller);
      case 3:
        return AskScreen(controller: controller);
      case 4:
        return RemindersScreen(controller: controller);
      case 5:
        return FamilyAssetsScreen(controller: controller);
      case 6:
        return SettingsScreen(controller: controller);
      case 0:
      default:
        return HomeScreen(controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pendingDeepLinkDocId = controller.pendingPlaybookDeepLinkDocId;
        if (pendingDeepLinkDocId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final targetDocId = controller.consumePendingPlaybookDeepLink();
            if (targetDocId != null && context.mounted) {
              Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (routeContext) => DocumentDetailScreen(
                    controller: controller,
                    documentId: targetDocId,
                    highlightPlaybook: true,
                  ),
                ),
              );
            }
          });
        }

        final tabIndex = controller.activeTabIndex;
        final bannerMessage = controller.statusBannerMessage;
        final bodyContent = _buildBodyForIndex(tabIndex);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;

            if (isDesktop) {
              return Scaffold(
                body: Row(
                  children: <Widget>[
                    _buildDesktopSidebar(context, tabIndex),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          _buildDesktopTopbar(context, tabIndex),
                          if (bannerMessage != null)
                            _buildStatusBanner(bannerMessage),
                          Expanded(child: bodyContent),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(_tabTitles[tabIndex.clamp(0, 6)]),
                actions: <Widget>[
                  IconButton(
                    key: const Key('topbar_reminders_button'),
                    tooltip: 'Reminders',
                    onPressed: () => controller.setActiveTab(4),
                    icon: const Icon(Icons.alarm_outlined),
                  ),
                  IconButton(
                    key: const Key('topbar_family_button'),
                    tooltip: 'Family & Assets',
                    onPressed: () => controller.setActiveTab(5),
                    icon: const Icon(Icons.people_outline),
                  ),
                  IconButton(
                    key: const Key('topbar_settings_button'),
                    tooltip: 'Settings & Privacy',
                    onPressed: () => controller.setActiveTab(6),
                    icon: const Icon(Icons.settings_outlined),
                  ),
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
                  if (bannerMessage != null) _buildStatusBanner(bannerMessage),
                  Expanded(child: bodyContent),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                key: const Key('app_bottom_navigation'),
                selectedIndex: tabIndex < 4 ? tabIndex : 0,
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
      },
    );
  }

  Widget _buildStatusBanner(String bannerMessage) {
    return MaterialBanner(
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
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, int activeIndex) {
    const items = <({int index, String label, IconData icon})>[
      (index: 0, label: 'Dashboard', icon: Icons.dashboard_outlined),
      (index: 2, label: 'My Documents', icon: Icons.folder_open_outlined),
      (index: 1, label: 'Scan & Upload', icon: Icons.document_scanner_outlined),
      (index: 3, label: 'Ask LifeVault', icon: Icons.chat_bubble_outline),
      (index: 4, label: 'Reminders', icon: Icons.alarm_outlined),
      (index: 5, label: 'Family & Assets', icon: Icons.people_outline),
      (index: 6, label: 'Settings & Privacy', icon: Icons.settings_outlined),
    ];

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: LifeVaultColors.sidebarBackground,
        border: Border(right: BorderSide(color: LifeVaultColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: LifeVaultColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'LifeVault',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: LifeVaultColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Private Family Vault',
                        style: TextStyle(
                          fontSize: 12,
                          color: LifeVaultColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: items.map((item) {
                final isSelected = activeIndex == item.index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    key: Key('sidebar_nav_${item.index}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => controller.setActiveTab(item.index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? LifeVaultColors.primaryLight
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? const Border(
                                left: BorderSide(
                                  color: LifeVaultColors.accent,
                                  width: 3,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected
                                ? LifeVaultColors.primary
                                : LifeVaultColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? LifeVaultColors.primary
                                    : LifeVaultColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: LifeVaultColors.success,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '100% Local Processing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LifeVaultColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.allDocuments.length} docs • '
                  '${controller.verifiedDeadlines.length} deadlines',
                  style: const TextStyle(
                    fontSize: 12,
                    color: LifeVaultColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openWelcomeScreen(context),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Welcome & Readiness'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTopbar(BuildContext context, int activeIndex) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: LifeVaultColors.surface,
        border: Border(bottom: BorderSide(color: LifeVaultColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            _tabTitles[activeIndex.clamp(0, 6)],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: LifeVaultColors.textPrimary,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => controller.setActiveTab(4),
            icon: const Icon(Icons.alarm_outlined, size: 18),
            label: Text('Deadlines (${controller.next30DaysCount})'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () => controller.setActiveTab(1),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Document'),
          ),
          const SizedBox(width: 12),
          const Chip(
            avatar: Icon(Icons.airplanemode_active, size: 16),
            label: Text('Offline'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
