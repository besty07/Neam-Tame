import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/contracts/contracts.dart';
import 'document_detail_screen.dart';
import 'review_screen.dart';

/// Home dashboard screen displaying summary metrics, overdue/upcoming
/// deadlines, and records needing verification (Section 4).
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
    final needsReview = controller.needsReviewDocuments;
    final overdue = controller.overdueItems;
    final upcoming = controller.upcomingItems;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildSummaryRow(
          context,
          totalDocs: totalDocs,
          next30Count: next30Count,
          needsReviewCount: needsReview.length,
        ),
        const SizedBox(height: 16),
        if (totalDocs == 0)
          _buildEmptyStateCard(context)
        else ...<Widget>[
          _buildDeadlineSection(
            context,
            title: 'Overdue',
            emptyText: 'No overdue deadlines.',
            items: overdue,
            accentColor: Colors.red.shade700,
          ),
          const SizedBox(height: 16),
          _buildDeadlineSection(
            context,
            title: 'Upcoming Deadlines',
            emptyText: 'No upcoming verified deadlines scheduled.',
            items: upcoming,
            accentColor: Colors.teal.shade700,
          ),
          const SizedBox(height: 16),
          _buildNeedsReviewSection(context, needsReview),
        ],
        const SizedBox(height: 20),
        _buildPrivacyFooter(context),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required int totalDocs,
    required int next30Count,
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
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetricTile(
            tileKey: const Key('summary_next30_tile'),
            label: 'Next 30 Days',
            value: '$next30Count',
            icon: Icons.event_note_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetricTile(
            tileKey: const Key('summary_needs_review_tile'),
            label: 'Needs Review',
            value: '$needsReviewCount',
            icon: Icons.fact_check_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.document_scanner_outlined,
              size: 48,
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
            Text(
              'Your Local Vault is Empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Photograph a policy, warranty, bill, or household document '
              'once. Find it instantly and never miss an important date.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
                Text(
                  '$title (${items.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(emptyText, style: Theme.of(context).textTheme.bodyMedium)
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
    if (days < 0) {
      remainingLabel = 'Overdue by ${days.abs()}d';
    } else if (days == 0) {
      remainingLabel = 'Due today';
    } else {
      remainingLabel = 'In ${days}d';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.document.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Chip(
                    label: Text(remainingLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.document.category.displayName} • '
                '${item.deadline.kind.displayName} • '
                'Due ${item.deadline.dateIso}',
                style: Theme.of(context).textTheme.bodySmall,
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (needsReview.isEmpty)
              const Text('All saved documents are verified.')
            else
              ...needsReview.map((doc) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pending_actions_outlined),
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

  Widget _buildPrivacyFooter(BuildContext context) {
    return Text(
      '100% On-Device Storage • No Cloud Sync or Network Access • '
      'Uninstalling the app deletes local vault files.',
      style: Theme.of(context).textTheme.bodySmall,
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
  });

  final Key tileKey;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: tileKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
