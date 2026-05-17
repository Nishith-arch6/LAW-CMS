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

class _CaseCard extends StatefulWidget {
  final CaseModel c;
  const _CaseCard(this.c);

  @override
  State<_CaseCard> createState() => _CaseCardState();
}

class _CaseCardState extends State<_CaseCard> {
  bool _isHovered = false;

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE': return const Color(0xFF10B981);
      case 'PENDING': return const Color(0xFFF59E0B);
      case 'CLOSED': return const Color(0xFF64748B);
      case 'ADJOURNED': return AppColors.accent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final statusCol = _statusColor(c.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        transform: _isHovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1E2E),
              const Color(0xFF161622).withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? statusCol.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => context.push('/cases/${c.id}'),
            borderRadius: BorderRadius.circular(16),
            splashColor: statusCol.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusCol.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusCol.withValues(alpha: 0.25), width: 1),
                              ),
                              child: Text(
                                c.statusDisplay,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusCol,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              c.caseNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          c.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (c.clientName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                c.clientName!,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ],
                        if (c.nextHearingDate != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: AppColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  'Next: ${c.nextHearingDate}',
                                  style: TextStyle(fontSize: 12, color: AppColors.accent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusCol.withValues(alpha: _isHovered ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.chevron_right, color: statusCol, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
