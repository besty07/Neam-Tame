import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import '../../core/contracts/contracts.dart';
import 'document_detail_screen.dart';
import 'review_screen.dart';

/// Vault screen providing local document search, 10-category filtering,
/// asset/member filtering, sorting, grid/list layouts, detail inspection,
/// recategorization, and deletion with confirmation (P0 spec).
class VaultScreen extends StatefulWidget {
  const VaultScreen({
    super.key,
    required this.controller,
  });

  final LifeVaultController controller;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.vaultSearchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(BuildContext context, DocumentRecord doc) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: doc.id,
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, DocumentRecord doc) async {
    final draft = widget.controller.createEditDraft(doc);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ReviewScreen(
          controller: widget.controller,
          draft: draft,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DocumentRecord doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Document?'),
          content: Text(
            'Delete "${doc.title}" from your local vault? '
            'This removes its copied image file and cancels its local '
            'reminders.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('vault_confirm_delete_button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.controller.deleteDocument(doc.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = widget.controller.selectedCategoryFilter;
    final selectedAsset = widget.controller.selectedAssetFilter;
    final documents = widget.controller.filteredDocuments;
    final isGrid = widget.controller.isVaultGridView;
    final sortOrder = widget.controller.vaultSortOrder;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('vault_search_field'),
                  controller: _searchController,
                  onChanged: widget.controller.setVaultSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search by title, category, type, or asset...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              widget.controller.setVaultSearchQuery('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<VaultSortOrder>(
                key: const Key('vault_sort_menu'),
                tooltip: 'Sort documents',
                initialValue: sortOrder,
                onSelected: widget.controller.setVaultSortOrder,
                icon: const Icon(Icons.sort),
                itemBuilder: (context) => VaultSortOrder.values.map((order) {
                  return PopupMenuItem<VaultSortOrder>(
                    value: order,
                    child: Text(order.label),
                  );
                }).toList(),
              ),
              IconButton(
                key: const Key('vault_view_toggle_button'),
                tooltip: isGrid ? 'Switch to list view' : 'Switch to grid view',
                onPressed: () => widget.controller.toggleVaultGridView(!isGrid),
                icon: Icon(
                  isGrid ? Icons.view_list_outlined : Icons.grid_view_outlined,
                ),
              ),
            ],
          ),
        ),
        if (selectedAsset != null && selectedAsset.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: <Widget>[
                InputChip(
                  label: Text('Asset / Member: $selectedAsset'),
                  onDeleted: () => widget.controller.filterVaultByAsset(null),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  key: const Key('vault_filter_all'),
                  label: const Text('All'),
                  selected: selectedCategory == null,
                  onSelected: (_) => widget.controller.setCategoryFilter(null),
                ),
              ),
              ...DocumentCategory.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: Key('vault_filter_${category.wireName}'),
                    label: Text(category.displayName),
                    selected: selectedCategory == category,
                    onSelected: (_) {
                      final next =
                          selectedCategory == category ? null : category;
                      widget.controller.setCategoryFilter(next);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: documents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.folder_off_outlined,
                          size: 44,
                          color: LifeVaultColors.textMuted,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No matching documents in your local vault.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => widget.controller.setActiveTab(1),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Document'),
                        ),
                      ],
                    ),
                  ),
                )
              : isGrid
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        mainAxisExtent: 170,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return _buildDocumentCard(context, doc);
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return _buildDocumentCard(context, doc);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(BuildContext context, DocumentRecord doc) {
    final deadlines = widget.controller.deadlinesForDocument(doc.id);
    String deadlineSubtitle = 'No deadline set';
    if (deadlines.isNotEmpty) {
      final first = deadlines.first;
      deadlineSubtitle = '${first.kind.displayName}: ${first.dateIso}';
    }

    String assetLabel = '';
    if (doc.assetName != null && doc.assetName!.isNotEmpty) {
      assetLabel = ' • Asset: ${doc.assetName}';
    }

    return Card(
      key: Key('vault_doc_card_${doc.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openDetail(context, doc),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: LifeVaultColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.description_outlined,
            color: LifeVaultColors.primary,
          ),
        ),
        title: Text(
          doc.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${doc.category.displayName} • '
              '${doc.documentType.displayName}$assetLabel',
            ),
            Text(
              '$deadlineSubtitle • '
              'Status: ${doc.verificationStatus.wireName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LifeVaultColors.textSecondary,
                  ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: Key('vault_edit_${doc.id}'),
              onPressed: () => _openEdit(context, doc),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit / Recategorize',
            ),
            IconButton(
              key: Key('vault_delete_${doc.id}'),
              onPressed: () => _confirmDelete(context, doc),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete document',
            ),
          ],
        ),
      ),
    );
  }
}
