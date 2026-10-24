import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../core/contracts/contracts.dart';
import 'document_detail_screen.dart';
import 'review_screen.dart';

/// Dedicated Reminders & Deadlines screen (`/reminders` P0 spec).
///
/// Displays household deadlines sorted by urgency, allows filtering by
/// overdue/upcoming states, configures advance-warning reminder schedules,
/// and clearly distinguishes stored local deadlines from OS notifications.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({
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
    final items = controller.filteredReminderItems;
    final activeFilter = controller.reminderFilter;
    final offsets = controller.defaultReminderOffsets;

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
                    'Reminders & Deadlines',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stay ahead of important household renewals, warranties, and bill due dates.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: LifeVaultColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: const Key('reminders_add_document_button'),
              onPressed: () => controller.setActiveTab(1),
              icon: const Icon(Icons.add_alarm_outlined, size: 18),
              label: const Text('Add Deadline Document'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_paused_outlined,
                      size: 18,
                      color: LifeVaultColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Advance Warning Schedule',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Stored reminders are always shown on your local dashboard. Android local notifications use inexact scheduling subject to OS notification permissions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LifeVaultColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _buildScheduleChip(
                      label: '30, 7 & 1 days before (Default)',
                      targetOffsets: const <int>[30, 7, 1],
                      currentOffsets: offsets,
                    ),
                    _buildScheduleChip(
                      label: '15 & 7 days before',
                      targetOffsets: const <int>[15, 7],
                      currentOffsets: offsets,
                    ),
                    _buildScheduleChip(
                      label: '7 days before only',
                      targetOffsets: const <int>[7],
                      currentOffsets: offsets,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReminderFilter.values.map((filter) {
            return ChoiceChip(
              key: Key('reminder_filter_${filter.name}'),
              label: Text(filter.label),
              selected: activeFilter == filter,
              onSelected: (_) => controller.setReminderFilter(filter),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: <Widget>[
                  const Icon(
                    Icons.event_available_outlined,
                    size: 44,
                    color: LifeVaultColors.accent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Deadlines in This View',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confirmed expiry and bill due dates from your documents will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...items.map((item) => _buildReminderCard(context, item)),
      ],
    );
  }

  Widget _buildScheduleChip({
    required String label,
    required List<int> targetOffsets,
    required List<int> currentOffsets,
  }) {
    final isSelected = targetOffsets.length == currentOffsets.length &&
        targetOffsets.every(currentOffsets.contains);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.setDefaultReminderOffsets(targetOffsets),
    );
  }

  Widget _buildReminderCard(BuildContext context, DashboardDeadlineItem item) {
    final isCompleted = controller.completedDeadlineIds.contains(
      item.deadline.id,
    );
    final days = item.daysRemaining;

    Color statusColor;
    Color statusBg;
    String statusText;

    if (isCompleted) {
      statusColor = LifeVaultColors.success;
      statusBg = LifeVaultColors.successBackground;
      statusText = 'Completed';
    } else if (days < 0) {
      statusColor = LifeVaultColors.danger;
      statusBg = LifeVaultColors.dangerBackground;
      statusText = 'Overdue by ${days.abs()}d';
    } else if (days == 0) {
      statusColor = LifeVaultColors.warning;
      statusBg = LifeVaultColors.warningBackground;
      statusText = 'Due today';
    } else if (days <= 14) {
      statusColor = LifeVaultColors.warning;
      statusBg = LifeVaultColors.warningBackground;
      statusText = 'Due Soon • In ${days}d';
    } else {
      statusColor = LifeVaultColors.primary;
      statusBg = LifeVaultColors.primaryLight;
      statusText = 'Upcoming • In ${days}d';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: Key('reminder_card_${item.deadline.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.document.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${item.document.category.displayName} • '
                '${item.deadline.kind.displayName} • '
                'Due ${item.deadline.dateIso} • '
                'Alerts: ${item.deadline.reminderOffsetsDays.join(", ")}d before',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LifeVaultColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () =>
                        controller.toggleDeadlineCompleted(item.deadline.id),
                    icon: Icon(
                      isCompleted
                          ? Icons.replay_outlined
                          : Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: Text(isCompleted ? 'Reopen' : 'Mark Complete'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        controller.scheduleReminderForDeadline(item.deadline),
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                    ),
                    label: const Text('Schedule Local Alert'),
                  ),
                  TextButton.icon(
                    onPressed: () => _editDocument(context, item.document),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Date'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openDocument(context, item.document.id),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View Document'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
