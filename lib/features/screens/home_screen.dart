import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../core/contracts/contracts.dart';
import 'document_detail_screen.dart';
import 'review_screen.dart';

/// Home dashboard screen displaying household welcome header, four statistics
/// cards, overdue/upcoming deadlines, quick actions, recently added documents,
/// and an interactive "Ask LifeVault" preview bar (P0 spec).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  Future<void> _openDocument(BuildContext context, String documentId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => DocumentDetailScreen(
          controller: controller,
          documentId: documentId,
        ),
      ),
    );
  }

  Future<void> _editDocument(
    BuildContext context,
    DocumentRecord document,
  ) async {
    final draft = controller.createEditDraft(document);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewScreen(
          controller: controller,
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDocs = controller.allDocuments.length;
    final next30Count = controller.next30DaysCount;
    final expiringSoonCount = controller.expiringSoonCount;
    final needsReview = controller.needsReviewDocuments;
    final overdue = controller.overdueItems;
    final upcoming = controller.upcomingItems;
    final recentDocs = controller.recentDocuments;
    final formattedToday = DateFormat(
      'EEE, MMM d, yyyy',
    ).format(controller.todayDateOnly);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildWelcomeHeader(context, formattedToday),
          const SizedBox(height: 10),
          _buildSummaryRow(
            context,
            totalDocs: totalDocs,
            next30Count: next30Count,
            expiringSoonCount: expiringSoonCount,
            needsReviewCount: needsReview.length,
          ),
          const SizedBox(height: 10),
          if (totalDocs == 0)
            _buildEmptyStateCard(context)
          else ...<Widget>[
            _buildDeadlineSection(
              context,
              title: 'Overdue',
              emptyText: 'No overdue deadlines.',
              items: overdue,
              accentColor: LifeVaultColors.danger,
            ),
            const SizedBox(height: 16),
            _buildDeadlineSection(
              context,
              title: 'Upcoming Deadlines',
              emptyText: 'No upcoming verified deadlines scheduled.',
              items: upcoming,
              accentColor: LifeVaultColors.primary,
            ),
            const SizedBox(height: 16),
            _buildNeedsReviewSection(context, needsReview),
            const SizedBox(height: 16),
            _buildRecentDocumentsSection(context, recentDocs),
          ],
          const SizedBox(height: 16),
          _buildQuickActionsSection(context),
          const SizedBox(height: 16),
          _buildAskPreviewCard(context),
          const SizedBox(height: 20),
          _buildPrivacyFooter(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, String formattedToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LifeVaultColors.surface,
        borderRadius: BorderRadius.circular(LifeVaultTheme.cardRadius),
        border: Border.all(color: LifeVaultColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your household, organized. • $formattedToday',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Everything important, all in one private place.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LifeVaultColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const Key('home_header_add_doc_button'),
            onPressed: () => controller.setActiveTab(1),
            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
            label: const Text('Add Document'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required int totalDocs,
    required int next30Count,
    required int expiringSoonCount,
    required int needsReviewCount,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryMetricTile(
            tileKey: const Key('summary_documents_tile'),
            label: 'Documents',
            value: '$totalDocs',
            icon: Icons.folder_copy_outlined,
            iconColor: LifeVaultColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetricTile(
            tileKey: const Key('summary_next30_tile'),
            label: 'Next 30 Days',
            value: '$next30Count',
            icon: Icons.event_note_outlined,
            iconColor: LifeVaultColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetricTile(
            tileKey: const Key('summary_expiring_soon_tile'),
            label: 'Expiring Soon',
            value: '$expiringSoonCount',
            icon: Icons.shield_outlined,
            iconColor: LifeVaultColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetricTile(
            tileKey: const Key('summary_needs_review_tile'),
            label: 'Needs Review',
            value: '$needsReviewCount',
            icon: Icons.fact_check_outlined,
            iconColor: needsReviewCount > 0
                ? LifeVaultColors.warning
                : LifeVaultColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.document_scanner_outlined,
              size: 32,
              color: LifeVaultColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              'Your Local Vault is Empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Photograph a policy, warranty, bill, or household document '
              'once. Find it instantly and never miss an important date.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('home_empty_scan_cta'),
              onPressed: () => controller.setActiveTab(1),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan First Document'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineSection(
    BuildContext context, {
    required String title,
    required String emptyText,
    required List<DashboardDeadlineItem> items,
    required Color accentColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.schedule, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title (${items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () => controller.setActiveTab(4),
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                emptyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LifeVaultColors.textSecondary,
                    ),
              )
            else
              ...items.map((item) => _buildDeadlineCard(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineCard(BuildContext context, DashboardDeadlineItem item) {
    final days = item.daysRemaining;
    String remainingLabel;
    Color chipBg;
    Color chipFg;

    if (days < 0) {
      remainingLabel = 'Overdue by ${days.abs()}d';
      chipBg = LifeVaultColors.dangerBackground;
      chipFg = LifeVaultColors.danger;
    } else if (days == 0) {
      remainingLabel = 'Due today';
      chipBg = LifeVaultColors.warningBackground;
      chipFg = LifeVaultColors.warning;
    } else if (days <= 14) {
      remainingLabel = 'In ${days}d';
      chipBg = LifeVaultColors.warningBackground;
      chipFg = LifeVaultColors.warning;
    } else {
      remainingLabel = 'In ${days}d';
      chipBg = LifeVaultColors.primaryLight;
      chipFg = LifeVaultColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LifeVaultColors.surfaceSecondary,
          border: Border.all(color: LifeVaultColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.document.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Chip(
                    backgroundColor: chipBg,
                    side: BorderSide.none,
                    label: Text(
                      remainingLabel,
                      style: TextStyle(
                        color: chipFg,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.document.category.displayName} • '
                '${item.deadline.kind.displayName} • '
                'Due ${item.deadline.dateIso}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LifeVaultColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  TextButton.icon(
                    key: Key('home_open_${item.deadline.id}'),
                    onPressed: () => _openDocument(context, item.document.id),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Open'),
                  ),
                  TextButton.icon(
                    key: Key('home_edit_${item.deadline.id}'),
                    onPressed: () => _editDocument(context, item.document),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    key: Key('home_remind_${item.deadline.id}'),
                    onPressed: () {
                      controller.scheduleReminderForDeadline(item.deadline);
                    },
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                    ),
                    label: const Text('Remind me'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedsReviewSection(
    BuildContext context,
    List<DocumentRecord> needsReview,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Needs Verification (${needsReview.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (needsReview.isEmpty)
              const Text('All saved documents are verified.')
            else
              ...needsReview.map((doc) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.pending_actions_outlined,
                    color: LifeVaultColors.warning,
                  ),
                  title: Text(doc.title),
                  subtitle: Text(
                    '${doc.category.displayName} • '
                    'Status: ${doc.verificationStatus.wireName}',
                  ),
                  trailing: OutlinedButton(
                    key: Key('home_verify_${doc.id}'),
                    onPressed: () => _editDocument(context, doc),
                    child: const Text('Review'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDocumentsSection(
    BuildContext context,
    List<DocumentRecord> recentDocs,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Recently Added (${recentDocs.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.setActiveTab(2),
                  child: const Text('Open Vault'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...recentDocs.map((doc) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _openDocument(context, doc.id),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: LifeVaultColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: LifeVaultColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  doc.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${doc.category.displayName} • ${doc.documentType.displayName}',
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const Key('quick_action_scan'),
                  onPressed: () => controller.setActiveTab(1),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Scan Document'),
                ),
                OutlinedButton.icon(
                  key: const Key('quick_action_upload'),
                  onPressed: () => controller.setActiveTab(1),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload File'),
                ),
                OutlinedButton.icon(
                  key: const Key('quick_action_ask'),
                  onPressed: () => controller.setActiveTab(3),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Ask LifeVault'),
                ),
                OutlinedButton.icon(
                  key: const Key('quick_action_reminders'),
                  onPressed: () => controller.setActiveTab(4),
                  icon: const Icon(Icons.alarm_outlined, size: 18),
                  label: const Text('View Reminders'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAskPreviewCard(BuildContext context) {
    const sampleQuestion = 'When does my bike insurance expire?';
    return Card(
      color: LifeVaultColors.primaryLight,
      child: InkWell(
        key: const Key('home_ask_preview_card'),
        borderRadius: BorderRadius.circular(LifeVaultTheme.cardRadius),
        onTap: () => controller.askQuestionAndNavigate(sampleQuestion),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LifeVaultColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.question_answer_outlined,
                  color: LifeVaultColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Have a question?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: LifeVaultColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '"$sampleQuestion" — tap to ask your local vault',
                      style: TextStyle(
                        fontSize: 13,
                        color: LifeVaultColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: LifeVaultColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyFooter(BuildContext context) {
    return Text(
      '100% On-Device Storage • No Cloud Sync or Network Access • '
      'Uninstalling the app deletes local vault files.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: LifeVaultColors.textSecondary,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.tileKey,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final Key tileKey;
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: tileKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LifeVaultColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
