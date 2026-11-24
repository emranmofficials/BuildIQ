import 'dart:async';

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

import 'package:provider/provider.dart';

import '../core/app_state.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<AppState>().projects;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('projects'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: projects.isEmpty
          ? Center(child: Text(context.t('noProjects')))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        project.name.isNotEmpty ? project.name[0] : '?',
                      ),
                    ),
                    title: Text(project.name),
                    subtitle: Text(
                      '${project.clientName} · ${project.status.name} · '
                      '${(project.budgetMinor / 100).toStringAsFixed(0)} '
                      '${project.currency}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, project.id),
                    ),
                    onTap: () => _showProjectDetail(context, project),
                  ),
                );
              },
            ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final name = TextEditingController();
    final client = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final budget = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('newProject')),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: context.t('projectName'),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.t('validationError')
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: client,
                  decoration: InputDecoration(labelText: context.t('client')),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: budget,
                  decoration: InputDecoration(labelText: context.t('budget')),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              unawaited(
                context.read<AppState>().createProject(
                  name: name.text.trim(),
                  clientName: client.text.trim(),
                  clientPhone: phone.text.trim(),
                  address: address.text.trim(),
                  budgetMinor: ((double.tryParse(budget.text) ?? 0) * 100)
                      .round(),
                  status: ProjectStatus.planning,
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('delete')),
        content: Text(context.t('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              unawaited(context.read<AppState>().deleteProject(id));
              Navigator.pop(dialogContext);
            },
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );
  }

  void _showProjectDetail(BuildContext context, Project project) {
    final saved = context.read<AppState>().savedCalculations.where(
      (row) => row['project_id'] == project.id,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(16),
          itemCount: saved.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('${context.t('client')}: ${project.clientName}'),
                  Text(
                    '${context.t('budget')}: ${(project.budgetMinor / 100).toStringAsFixed(0)} ${project.currency}',
                  ),
                  Text('${context.t('status')}: ${project.status.name}'),
                  const Divider(),
                  Text(
                    context.t('saved'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              );
            }
            final row = saved.elementAt(index - 1);
            return ListTile(
              title: Text(row['title'] as String? ?? ''),
              subtitle: Text(row['kind'] as String? ?? ''),
            );
          },
        ),
      ),
    );
  }
}
