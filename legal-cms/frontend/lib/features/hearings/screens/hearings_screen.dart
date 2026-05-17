import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../providers/hearings_provider.dart';
import '../../cases/providers/cases_provider.dart';
import '../../../shared/models/hearing_model.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/widgets/hearing_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_client.dart';

class HearingsScreen extends ConsumerStatefulWidget {
  const HearingsScreen({super.key});

  @override
  ConsumerState<HearingsScreen> createState() => _HearingsScreenState();
}

class _HearingsScreenState extends ConsumerState<HearingsScreen> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _showCalendar = true;
  String _listFilter = 'upcoming';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(hearingsProvider.notifier).loadHearings());
  }

  Map<DateTime, List<HearingModel>> _groupByDate(List<HearingModel> list) {
    final map = <DateTime, List<HearingModel>>{};
    for (final h in list) {
      final dt = DateTime.tryParse(h.hearingDate) ?? DateTime.now();
      final day = DateTime(dt.year, dt.month, dt.day);
      map.putIfAbsent(day, () => []).add(h);
    }
    return map;
  }

  List<HearingModel> _filteredList(List<HearingModel> all) {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    switch (_listFilter) {
      case 'today':
        return all.where((h) => h.hearingDate == todayStr).toList();
      case 'past':
        return all.where((h) => (h.hearingDate.compareTo(todayStr) < 0)).toList();
      default:
        return all.where((h) => h.hearingDate.compareTo(todayStr) >= 0).toList();
    }
  }

  void _showHearingDetail(HearingModel h) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _HearingDetailSheet(hearing: h),
    );
  }

  void _showAddHearing() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddHearingSheet(),
    );
  }

  Widget _filterRow() {
    return Row(
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Calendar')),
            ButtonSegment(value: false, label: Text('List')),
          ],
          selected: {_showCalendar},
          onSelectionChanged: (v) => setState(() => _showCalendar = v.first),
        ),
        const Spacer(),
        Flexible(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'upcoming', label: Text('Upcoming')),
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(value: 'past', label: Text('Past')),
            ],
            selected: {_listFilter},
            onSelectionChanged: (v) => setState(() => _listFilter = v.first),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, Map<DateTime, List<HearingModel>> grouped) {
    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
      onDaySelected: (d, f) => setState(() {
        _selectedDay = d;
        _focusedDay = f;
      }),
      onFormatChanged: (f) => setState(() => _format = f),
      onPageChanged: (d) => _focusedDay = d,
      calendarFormat: _format,
      eventLoader: (d) => grouped[d] ?? [],
      calendarBuilders: CalendarBuilders(
        markerBuilder: (_, date, events) {
          if (events.isEmpty) return null;
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: AppColors.secondary, shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hearingList(HearingsState state, List<HearingModel> filtered) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (filtered.isEmpty) return const EmptyState(icon: Icons.event_busy, title: 'No hearings found');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => HearingCard(
        hearing: filtered[i],
        onTap: () => _showHearingDetail(filtered[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hearingsProvider);
    final hearings = state.hearings;
    final grouped = _groupByDate(hearings);
    final filtered = _filteredList(hearings);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _filterRow(),
                      ),
                      if (_showCalendar)
                        Card(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _buildCalendar(context, grouped),
                        ),
                      if (grouped[_selectedDay] != null && _showCalendar)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text('${grouped[_selectedDay]!.length} hearing(s) on ${DateFormat('MMM dd, yyyy').format(_selectedDay)}',
                            style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          _showCalendar && grouped[_selectedDay] != null
                              ? 'Hearings on ${DateFormat('MMM dd, yyyy').format(_selectedDay)}'
                              : 'All Hearings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: _hearingList(state, filtered)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _filterRow(),
                ),
                if (_showCalendar)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _buildCalendar(context, grouped),
                  ),
                if (grouped[_selectedDay] != null && _showCalendar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('${grouped[_selectedDay]!.length} hearing(s) on ${DateFormat('MMM dd, yyyy').format(_selectedDay)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  ),
                const SizedBox(height: 4),
                Expanded(child: _hearingList(state, filtered)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHearing,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HearingDetailSheet extends StatelessWidget {
  final HearingModel hearing;
  const _HearingDetailSheet({required this.hearing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
            )),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(hearing.purpose ?? 'Hearing', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              StatusBadgeWidget(status: hearing.status),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(Icons.calendar_today, 'Date', hearing.hearingDate),
          if (hearing.hearingTime != null)
            _detailRow(Icons.access_time, 'Time', hearing.hearingTime!.substring(0, 5)),
          if (hearing.courtRoom != null)
            _detailRow(Icons.meeting_room, 'Room', hearing.courtRoom!),
          if (hearing.notes != null)
            _detailRow(Icons.notes, 'Notes', hearing.notes!),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.cancel, size: 18, color: AppColors.error),
                label: const Text('Cancel', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }
}

class StatusBadgeWidget extends StatelessWidget {
  final String status;
  const StatusBadgeWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status.toUpperCase()) {
      case 'SCHEDULED': c = AppColors.secondary;
      case 'COMPLETED': c = AppColors.success;
      case 'ADJOURNED': c = AppColors.warning;
      case 'CANCELLED': c = AppColors.error;
      default: c = Colors.grey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: c,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _AddHearingSheet extends ConsumerStatefulWidget {
  const _AddHearingSheet();

  @override
  ConsumerState<_AddHearingSheet> createState() => _AddHearingSheetState();
}

class _AddHearingSheetState extends ConsumerState<_AddHearingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _purposeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _courtRoomCtrl = TextEditingController();

  String _hearingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _hearingTime;
  String _status = 'SCHEDULED';
  int? _selectedCaseId;
  List<CaseModel> _cases = [];
  bool _casesLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _casesLoading = true);
      await ref.read(casesProvider.notifier).loadCases(refresh: true);
      if (mounted) {
        setState(() {
          _cases = ref.read(casesProvider).cases;
          _casesLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _notesCtrl.dispose();
    _courtRoomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _hearingDate = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _hearingTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a case')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(hearingsProvider.notifier).createHearing(
        HearingCreateRequest(
          caseId: _selectedCaseId!,
          hearingDate: _hearingDate,
          hearingTime: _hearingTime,
          courtRoom: _courtRoomCtrl.text.trim().isEmpty ? null : _courtRoomCtrl.text.trim(),
          purpose: _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          status: _status,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // error handled by provider
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
            ))),
            const SizedBox(height: 16),
            Text('Schedule Hearing', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _casesLoading
                ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : DropdownButtonFormField<int>(
                    value: _selectedCaseId,
                    decoration: const InputDecoration(labelText: 'Case *'),
                    isExpanded: true,
                    hint: const Text('Select a case'),
                    items: _cases.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.caseNumber} — ${c.title} (${c.clientName ?? "N/A"})'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCaseId = v!),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today)),
                child: Text(_hearingDate),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Time', suffixIcon: Icon(Icons.access_time)),
                child: Text(_hearingTime ?? 'Select time (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purposeCtrl,
              decoration: const InputDecoration(labelText: 'Purpose'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _courtRoomCtrl,
              decoration: const InputDecoration(labelText: 'Court Room'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ['SCHEDULED', 'COMPLETED', 'ADJOURNED', 'CANCELLED']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Schedule'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
