import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/document_model.dart';
import '../../../shared/models/hearing_model.dart';
import '../../../shared/models/case_note_model.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/cases_provider.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final int caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(casesProvider.notifier).loadCaseDetail(widget.caseId);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(casesProvider);
    final c = state.caseDetail;
    final theme = Theme.of(context);

    if (state.isLoadingDetail) {
      return Scaffold(appBar: const GradientAppBar(title: Text('Case Details')), body: const Center(child: CircularProgressIndicator()));
    }

    if (c == null) {
      return Scaffold(
        appBar: const GradientAppBar(title: Text('Case Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(state.error ?? 'Case not found', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(c.caseNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/cases/${c.id}/edit'),
          ),
        ],
      ),
      body: isWide
          ? Column(
              children: [
                _CaseHeader(c: c),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SingleChildScrollView(child: _OverviewTab(c: c))),
                        const SizedBox(width: 16),
                        Expanded(child: _HearingsTab(hearings: state.caseHearings, caseId: c.id)),
                        const SizedBox(width: 16),
                        Expanded(child: _DocumentsTab(documents: state.caseDocuments, caseId: c.id)),
                        const SizedBox(width: 16),
                        Expanded(child: _NotesTab(notes: state.caseNotes, caseId: c.id)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _CaseHeader(c: c),
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Hearings'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Notes'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _OverviewTab(c: c),
                      _HearingsTab(hearings: state.caseHearings, caseId: c.id),
                      _DocumentsTab(documents: state.caseDocuments, caseId: c.id),
                      _NotesTab(notes: state.caseNotes, caseId: c.id),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CaseHeader extends StatelessWidget {
  final dynamic c;

  const _CaseHeader({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(c.statusDisplay, style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: _statusColor(c.status),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(c.caseType, style: const TextStyle(fontSize: 11)),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
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

class _OverviewTab extends StatelessWidget {
  final dynamic c;

  const _OverviewTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_InfoItem>[
      _InfoItem('Case Number', c.caseNumber),
      _InfoItem('Title', c.title),
      _InfoItem('Case Type', c.caseType),
      _InfoItem('Status', c.statusDisplay),
      if (c.courtName != null) _InfoItem('Court', c.courtName),
      if (c.courtBuilding != null) _InfoItem('Building', c.courtBuilding),
      if (c.courtFloor != null) _InfoItem('Floor', c.courtFloor),
      if (c.judgeName != null) _InfoItem('Judge', c.judgeName),
      if (c.clientName != null) _InfoItem('Client', c.clientName),
      if (c.opposingParty != null) _InfoItem('Opposing Party', c.opposingParty),
      if (c.defendingParty != null) _InfoItem('Defending Party', c.defendingParty),
      if (c.filingDate != null) _InfoItem('Filing Date', c.filingDate),
      if (c.description != null) _InfoItem('Description', c.description),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(item.label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ),
                    Expanded(
                      child: Text(item.value, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

class _HearingsTab extends StatelessWidget {
  final List<HearingModel> hearings;
  final int caseId;

  const _HearingsTab({required this.hearings, required this.caseId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<HearingModel>.from(hearings)
      ..sort((a, b) => b.hearingDate.compareTo(a.hearingDate));

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No hearings', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final h = sorted[i];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.gavel, color: AppColors.secondary, size: 20),
          ),
          title: Text(h.purpose ?? 'Hearing'),
          subtitle: Text('${h.hearingDate}  ${h.hearingTime ?? ""}  ${h.courtRoom ?? ""}'),
          trailing: Chip(
            label: Text(h.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: _statusColor(h.status),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
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

class _DocumentsTab extends ConsumerWidget {
  final List<DocumentModel> documents;
  final int caseId;

  const _DocumentsTab({required this.documents, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No documents', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final d = documents[i];
        return ExpansionTile(
          leading: _fileIcon(d.fileType),
          title: Text(d.fileName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          subtitle: Text('${d.formattedSize}  |  ${d.uploadedAt ?? ""}'),
          children: [
            if (d.description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(d.description!, style: theme.textTheme.bodySmall),
              ),
            if (d.ocrText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OCR Text:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.ocrText!, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fileIcon(String? type) {
    IconData icon;
    if (type == null) {
      icon = Icons.insert_drive_file;
    } else if (type.contains('pdf')) {
      icon = Icons.picture_as_pdf;
    } else if (type.contains('image')) {
      icon = Icons.image;
    } else if (type.contains('word') || type.contains('document')) {
      icon = Icons.description;
    } else {
      icon = Icons.insert_drive_file;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }
}

class _NotesTab extends StatelessWidget {
  final List<CaseNoteModel> notes;
  final int caseId;

  const _NotesTab({required this.notes, required this.caseId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = List<CaseNoteModel>.from(notes)
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No notes', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final n = sorted[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.person, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(n.authorName ?? 'Advocate', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(n.createdAt ?? '', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(n.content, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}
