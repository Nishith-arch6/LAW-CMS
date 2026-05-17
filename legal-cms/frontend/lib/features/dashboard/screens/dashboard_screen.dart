import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../cases/providers/cases_provider.dart';
import '../../hearings/providers/hearings_provider.dart';
import '../../../shared/models/hearing_model.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/models/dashboard_models.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(casesProvider.notifier).loadDashboard();
      ref.read(hearingsProvider.notifier).loadTodayHearings();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(casesProvider.notifier).loadDashboard(),
      ref.read(hearingsProvider.notifier).loadTodayHearings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final casesState = ref.watch(casesProvider);
    final hearingsState = ref.watch(hearingsProvider);
    final stats = casesState.dashboardStats;
    final theme = Theme.of(context);

    final isWide = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _StatsGrid(stats: stats),
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _CaseTypeChart(stats: stats)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hearingsSection(theme, hearingsState),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _CaseTypeChart(stats: stats),
            const SizedBox(height: 16),
            _hearingsSection(theme, hearingsState),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Cases',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => context.go('/cases'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (casesState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (stats == null || stats.recentCases.isEmpty)
            Card(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('No recent cases', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))),
            ))
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stats.recentCases.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _RecentCaseCard(stats.recentCases[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hearingsSection(ThemeData theme, HearingsState hearingsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Hearings",
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (hearingsState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (hearingsState.todayHearings.isEmpty)
          Card(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('No hearings today', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))),
          ))
        else
          ...hearingsState.todayHearings.map((h) => _HearingTile(h)),
      ],
    );
  }
}

class _CaseTypeChart extends StatelessWidget {
  final DashboardStats? stats;

  const _CaseTypeChart({this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breakdown = stats?.caseTypeBreakdown ?? {};
    if (breakdown.isEmpty) return const SizedBox.shrink();

    const colors = [AppColors.primary, AppColors.secondary, AppColors.accent, AppColors.success, AppColors.warning];
    final entries = breakdown.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cases by Type', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 1,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${entries[groupIndex].key}\n${rod.toY.toInt()}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entries[idx].key.substring(0, 3),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}'))),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value.toDouble(),
                          color: colors[e.key % colors.length],
                          width: 22,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardStats? stats;

  const _StatsGrid({this.stats});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w < 600 ? 2 : w < 1024 ? 3 : 4;
    return GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: cols > 2 ? 1.8 : 1.6,
      children: [
        _StatCard(title: 'Total Cases', value: '${stats?.totalCases ?? 0}', icon: Icons.folder, color: AppColors.primary, onTap: () => context.go('/cases')),
        _StatCard(title: 'Active', value: '${stats?.activeCases ?? 0}', icon: Icons.rocket_launch, color: AppColors.secondary, onTap: () => context.go('/cases')),
        _StatCard(title: "Today's Hearings", value: '${stats?.pendingHearingsToday ?? 0}', icon: Icons.today, color: AppColors.accent, onTap: () => context.go('/hearings?filter=today')),
        _StatCard(title: 'Upcoming (Week)', value: '${stats?.pendingHearingsWeek ?? 0}', icon: Icons.date_range, color: AppColors.success, onTap: () => context.go('/hearings')),
      ],
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [widget.color.withAlpha(_hovered ? 50 : 30), widget.color.withAlpha(_hovered ? 25 : 10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.value,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold, color: widget.color)),
                        Text(widget.title,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
                      ],
                    ),
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

class _HearingTile extends StatefulWidget {
  final HearingModel hearing;

  const _HearingTile(this.hearing);

  @override
  State<_HearingTile> createState() => _HearingTileState();
}

class _HearingTileState extends State<_HearingTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = widget.hearing;
    final time = h.hearingTime != null ? h.hearingTime!.substring(0, 5) : '--:--';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/hearings?filter=today'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          child: Card(
            elevation: _hovered ? 3 : 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gavel, color: AppColors.secondary),
              ),
              title: Text(h.purpose ?? 'Hearing', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('${h.caseTitle ?? "Case #${h.caseId}"}  |  $time  ${h.courtRoom ?? ""}'),
              trailing: Chip(
                label: Text(h.status, style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: _statusColor(h.status),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'SCHEDULED': return AppColors.secondary;
      case 'COMPLETED': return AppColors.success;
      case 'ADJOURNED': return AppColors.warning;
      case 'CANCELLED': return AppColors.error;
      default: return Colors.grey;
    }
  }
}

class _RecentCaseCard extends StatefulWidget {
  final CaseSummaryModel c;

  const _RecentCaseCard(this.c);

  @override
  State<_RecentCaseCard> createState() => _RecentCaseCardState();
}

class _RecentCaseCardState extends State<_RecentCaseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/cases/${widget.c.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          width: 200,
          child: Card(
            elevation: _hovered ? 4 : 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(widget.c.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: _statusColor(widget.c.status),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Spacer(),
                  Text(widget.c.caseNumber, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  Text(widget.c.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (widget.c.clientName != null) Text(widget.c.clientName!, style: theme.textTheme.bodySmall),
                ],
              ),
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
