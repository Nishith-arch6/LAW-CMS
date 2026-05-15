import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/clients_provider.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../core/theme/app_theme.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  final int clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(clientsProvider.notifier).loadClientDetail(widget.clientId);
      ref.read(clientsProvider.notifier).loadClientCases(widget.clientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientsProvider);
    final client = state.clientDetail;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(client?.name ?? 'Client Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/clients/${widget.clientId}/edit'),
          ),
        ],
      ),
      body: state.isLoadingDetail
          ? const Center(child: CircularProgressIndicator())
          : client == null
              ? const Center(child: Text('Client not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withAlpha(25),
                        child: Text(client.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(client.name, textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Contact Information', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            if (client.email != null) _row(Icons.email, 'Email', client.email!),
                            if (client.phone != null) _row(Icons.phone, 'Phone', client.phone!),
                            if (client.address != null) _row(Icons.location_on, 'Address', client.address!),
                            if (client.notes != null) _row(Icons.notes, 'Notes', client.notes!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Linked Cases', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (state.clientCases.isEmpty)
                      const EmptyState(icon: Icons.folder_off, title: 'No linked cases')
                    else
                      ...state.clientCases.map((c) => _CaseLinkTile(caseModel: c)),
                  ],
                ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CaseLinkTile extends StatelessWidget {
  final CaseModel caseModel;

  const _CaseLinkTile({required this.caseModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/cases/${caseModel.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(status: caseModel.status),
                        const SizedBox(width: 8),
                        Text(caseModel.caseNumber, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(caseModel.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
