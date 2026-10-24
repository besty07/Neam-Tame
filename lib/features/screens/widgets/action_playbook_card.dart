import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/contracts/contracts.dart';

/// Interactive Action Playbook card displayed in `DocumentDetailScreen`
/// (`QWEN_INTEGRATION_PLAN.md` Phase 3).
class ActionPlaybookCard extends StatelessWidget {
  const ActionPlaybookCard({
    super.key,
    required this.playbook,
    required this.onToggleStep,
    this.isLoading = false,
    this.isHighlighted = false,
  });

  final ActionPlaybook? playbook;
  final void Function(String stepId) onToggleStep;
  final bool isLoading;
  final bool isHighlighted;

  Future<void> _copyIdentifier(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$text" to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && playbook == null) {
      return const Card(
        key: Key('action_playbook_loading_card'),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Generating offline Action Playbook...'),
              ),
            ],
          ),
        ),
      );
    }

    final activePlaybook = playbook;
    if (activePlaybook == null) {
      return const SizedBox.shrink();
    }

    final completedCount =
        activePlaybook.steps.where((step) => step.isCompleted).length;
    final totalCount = activePlaybook.steps.length;
    final isQwen = activePlaybook.source == PlaybookSource.qwen;

    return Card(
      key: const Key('action_playbook_card'),
      shape: isHighlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.checklist_rtl_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Action Playbook',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  key: const Key('action_playbook_source_chip'),
                  avatar: Icon(
                    isQwen ? Icons.auto_awesome : Icons.verified_user_outlined,
                    size: 15,
                  ),
                  label: Text(
                    activePlaybook.source.displayName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              activePlaybook.summary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$completedCount of $totalCount preparation tasks completed',
              key: const Key('action_playbook_progress_text'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Divider(height: 20),
            ...activePlaybook.steps.map((step) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: step.isCompleted
                        ? Colors.teal.withOpacity(0.06)
                        : Colors.transparent,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Checkbox(
                              key: Key('playbook_checkbox_${step.id}'),
                              value: step.isCompleted,
                              onChanged: (_) => onToggleStep(step.id),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => onToggleStep(step.id),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 10,
                                    bottom: 6,
                                    right: 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        step.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: step.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        step.description,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (step.copyableText != null &&
                            step.copyableText!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 48,
                              right: 8,
                              bottom: 6,
                            ),
                            child: OutlinedButton.icon(
                              key: Key('playbook_copy_${step.id}'),
                              onPressed: () => _copyIdentifier(
                                context,
                                step.copyableText!,
                              ),
                              icon: const Icon(Icons.copy_outlined, size: 15),
                              label: Text(
                                'Copy ID: ${step.copyableText}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
