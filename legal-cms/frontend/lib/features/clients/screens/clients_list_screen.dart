import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/clients_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(clientsProvider.notifier).loadClients(refresh: true));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    ref.read(clientsProvider.notifier).setSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.clients.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No clients yet',
                        subtitle: 'Add your first client',
                      )
                    : LayoutBuilder(
                        builder: (_, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          if (isWide) {
                            final cols = (constraints.maxWidth / 300).floor().clamp(2, 3);
                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: cols > 2 ? 3.5 : 3.0,
                              ),
                              itemCount: state.clients.length,
                              itemBuilder: (_, i) => _clientCard(state.clients[i], theme, context),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.clients.length,
                            itemBuilder: (_, i) => _clientCard(state.clients[i], theme, context),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _clientCard(dynamic c, ThemeData theme, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.gradientStart.withAlpha(8), AppColors.secondary.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white.withAlpha(240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => context.push('/clients/${c.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: Text(c.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      if (c.email != null)
                        _infoText(c.email!, Icons.email_outlined),
                      if (c.phone != null)
                        _infoText(c.phone!, Icons.phone_outlined),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: AppColors.primary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoText(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
