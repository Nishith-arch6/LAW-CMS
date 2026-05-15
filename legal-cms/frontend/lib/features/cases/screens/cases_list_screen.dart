import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/cases_provider.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';

class CasesListScreen extends ConsumerStatefulWidget {
  const CasesListScreen({super.key});

  @override
  ConsumerState<CasesListScreen> createState() => _CasesListScreenState();
}

class _CasesListScreenState extends ConsumerState<CasesListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _filters = ['All', 'Active', 'Pending', 'Closed'];
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(casesProvider.notifier).loadCases(refresh: true));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(casesProvider.notifier).loadCases();
    }
  }

  void _onSearch(String q) {
    ref.read(casesProvider.notifier).setSearch(q);
  }

  void _onFilter(int i) {
    setState(() => _selectedFilter = i);
    final status = i == 0 ? '' : _filters[i].toUpperCase();
    ref.read(casesProvider.notifier).setStatusFilter(status);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(casesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search cases...',
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
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => FilterChip(
                label: Text(_filters[i]),
                selected: _selectedFilter == i,
                onSelected: (_) => _onFilter(i),
                selectedColor: AppColors.primary.withAlpha(30),
                checkmarkColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(state.error!, style: const TextStyle(color: AppColors.error)),
            ),
          Expanded(
            child: state.isLoading && state.cases.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.cases.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_off, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No cases found', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (_, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          if (isWide) {
                            final cols = (constraints.maxWidth / 280).floor().clamp(2, 4);
                            return GridView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: cols > 3 ? 3.5 : 2.8,
                              ),
                              itemCount: state.cases.length + (state.isLoading ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= state.cases.length) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ));
                                }
                                return _CaseCard(state.cases[i]);
                              },
                            );
                          }
                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.cases.length + (state.isLoading ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= state.cases.length) {
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ));
                              }
                              return _CaseCard(state.cases[i]);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/cases/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CaseCard extends ConsumerWidget {
  final CaseModel c;

  const _CaseCard(this.c);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.secondary.withAlpha(8), AppColors.primary.withAlpha(8)],
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
          onTap: () => context.push('/cases/${c.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(c.status).withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(c.statusDisplay,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: _statusColor(c.status))),
                          ),
                          const SizedBox(width: 8),
                          Text(c.caseNumber,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(c.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (c.clientName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 13, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(c.clientName!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      if (c.nextHearingDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 11, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text('Next: ${c.nextHearingDate}',
                                        style: TextStyle(fontSize: 11, color: AppColors.accent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: AppColors.secondary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE': return AppColors.secondary;
      case 'PENDING': return AppColors.warning;
      case 'CLOSED': return AppColors.success;
      case 'ADJOURNED': return AppColors.accent;
      default: return Colors.grey;
    }
  }
}
