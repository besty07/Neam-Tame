import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import 'review_screen.dart';

/// Family Members & Household Assets screen (`/family` spec).
///
/// Groups documents and deadlines by household member or valuable asset
/// (vehicles, appliances, utilities) and supports basic text-based ownership
/// labels per the hackathon rule.
class FamilyAssetsScreen extends StatelessWidget {
  const FamilyAssetsScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  Future<void> _promptAddEntity(
    BuildContext context, {
    required bool isMember,
  }) async {
    final textController = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isMember ? 'Add Household Member' : 'Add Household Asset',
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: isMember ? 'Member Name' : 'Asset Name',
              hintText: isMember
                  ? 'e.g., Priya, Arjun, Parents'
                  : 'e.g., Honda Activa, Samsung Fridge, Car',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added != null && added.isNotEmpty) {
      if (isMember) {
        controller.addHouseholdMember(added);
      } else {
        controller.addHouseholdAsset(added);
      }
    }
  }

  Future<void> _assignNewDocument(
    BuildContext context,
    String entityName,
  ) async {
    final draft = controller.createManualEntryDraft(
      initialAssetName: entityName,
    );
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
    final members = controller.householdMembers;
    final assets = controller.householdAssets;

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
                    'Family & Household Assets',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organize policies, warranties, and records by family member or household asset.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: LifeVaultColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const Key('family_add_member_button'),
                  onPressed: () => _promptAddEntity(context, isMember: true),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Add Member'),
                ),
                FilledButton.icon(
                  key: const Key('family_add_asset_button'),
                  onPressed: () => _promptAddEntity(context, isMember: false),
                  icon: const Icon(Icons.add_home_work_outlined, size: 18),
                  label: const Text('Add Asset'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Family Members (${members.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        ...members.map((m) => _buildEntityCard(context, m, isMember: true)),
        const SizedBox(height: 20),
        Text(
          'Household Assets (${assets.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        if (assets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 40,
                    color: LifeVaultColors.primary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No named assets yet. Add a vehicle, appliance, or utility asset to group its documents and warranties.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _promptAddEntity(context, isMember: false),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Asset'),
                  ),
                ],
              ),
            ),
          )
        else
          ...assets.map((a) => _buildEntityCard(context, a, isMember: false)),
      ],
    );
  }

  Widget _buildEntityCard(
    BuildContext context,
    HouseholdEntitySummary entity, {
    required bool isMember,
  }) {
    final deadlineLabel = entity.nearestDeadlineIso != null
        ? 'Nearest deadline: ${entity.nearestDeadlineIso}'
        : 'No upcoming deadlines';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isMember
                      ? LifeVaultColors.primaryLight
                      : LifeVaultColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isMember ? Icons.person_outline : Icons.inventory_2_outlined,
                  color: isMember
                      ? LifeVaultColors.primary
                      : LifeVaultColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entity.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entity.documentCount} document(s) • '
                      '${entity.upcomingDeadlineCount} deadline(s) • '
                      '$deadlineLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: LifeVaultColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _assignNewDocument(context, entity.name),
                    icon: const Icon(Icons.note_add_outlined, size: 16),
                    label: const Text('Assign Doc'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => controller.filterVaultByAsset(entity.name),
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: const Text('View Docs'),
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
