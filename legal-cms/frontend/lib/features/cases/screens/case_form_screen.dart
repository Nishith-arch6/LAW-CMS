import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../providers/cases_provider.dart';
import '../providers/ml_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../../../shared/models/case_model.dart';
import '../../../shared/models/client_model.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class CaseFormScreen extends ConsumerStatefulWidget {
  final int? caseId;

  const CaseFormScreen({super.key, this.caseId});

  @override
  ConsumerState<CaseFormScreen> createState() => _CaseFormScreenState();
}

class _CaseFormScreenState extends ConsumerState<CaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _courtNameCtrl = TextEditingController();
  final _courtBuildingCtrl = TextEditingController();
  final _courtFloorCtrl = TextEditingController();
  final _judgeCtrl = TextEditingController();
  final _opposingCtrl = TextEditingController();
  final _defendingCtrl = TextEditingController();
  final _clientSearchCtrl = TextEditingController();

  String _caseType = 'CIVIL';
  String _status = 'ACTIVE';
  int? _selectedClientId;
  String? _selectedClientName;
  String? _filingDate;
  bool _isSubmitting = false;

  final _caseTypes = ['CIVIL', 'CRIMINAL', 'FAMILY', 'CORPORATE', 'OTHER'];
  final _statuses = ['ACTIVE', 'PENDING', 'CLOSED', 'ADJOURNED'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(clientsProvider.notifier).loadClients(refresh: true);
      if (widget.caseId != null) {
        ref.read(casesProvider.notifier).loadCaseDetail(widget.caseId!);
      }
    });
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _courtNameCtrl.dispose();
    _courtBuildingCtrl.dispose();
    _courtFloorCtrl.dispose();
    _judgeCtrl.dispose();
    _opposingCtrl.dispose();
    _defendingCtrl.dispose();
    _clientSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTitleChanged(String title) async {
    if (title.length > 5) {
      ref.read(mlProvider.notifier).suggestCategory(title, _descCtrl.text);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _filingDate = picked.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final req = CaseCreateRequest(
        caseNumber: _numberCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        caseType: _caseType,
        status: _status,
        courtName: _courtNameCtrl.text.trim().isEmpty ? null : _courtNameCtrl.text.trim(),
        courtBuilding: _courtBuildingCtrl.text.trim().isEmpty ? null : _courtBuildingCtrl.text.trim(),
        courtFloor: _courtFloorCtrl.text.trim().isEmpty ? null : _courtFloorCtrl.text.trim(),
        judgeName: _judgeCtrl.text.trim().isEmpty ? null : _judgeCtrl.text.trim(),
        clientId: _selectedClientId!,
        opposingParty: _opposingCtrl.text.trim().isEmpty ? null : _opposingCtrl.text.trim(),
        defendingParty: _defendingCtrl.text.trim().isEmpty ? null : _defendingCtrl.text.trim(),
        filingDate: _filingDate,
      );

      await ref.read(casesProvider.notifier).createCase(req);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case created successfully')),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(casesProvider).error ?? 'Failed to create case')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsState = ref.watch(clientsProvider);
    final mlState = ref.watch(mlProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: Text(widget.caseId != null ? 'Edit Case' : 'New Case')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Case Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(labelText: 'Case Number *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  suffixIcon: Icon(Icons.auto_awesome),
                ),
                onChanged: _onTitleChanged,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              if (mlState is AsyncData<MlSuggestion?> && mlState.value != null)
                Card(
                  color: AppColors.success.withAlpha(20),
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome, color: AppColors.success),
                    title: Text('Suggested: ${mlState.value!.category}'),
                    subtitle: Text('Confidence: ${(mlState.value!.confidence * 100).toStringAsFixed(0)}%'),
                    trailing: TextButton(
                      onPressed: () => setState(() => _caseType = mlState.value!.category),
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _caseType,
                      decoration: const InputDecoration(labelText: 'Case Type'),
                      items: _caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _caseType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('Court Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _courtNameCtrl,
                decoration: const InputDecoration(labelText: 'Court Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _courtBuildingCtrl,
                      decoration: const InputDecoration(labelText: 'Building'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _courtFloorCtrl,
                      decoration: const InputDecoration(labelText: 'Floor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _judgeCtrl,
                decoration: const InputDecoration(labelText: 'Judge Name'),
              ),
              const SizedBox(height: 16),

              Text('Parties', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showClientPicker(clientsState.clients),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Client *',
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(_selectedClientName ?? 'Select a client'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _opposingCtrl,
                decoration: const InputDecoration(labelText: 'Opposing Party'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defendingCtrl,
                decoration: const InputDecoration(labelText: 'Defending Party'),
              ),
              const SizedBox(height: 16),

              Text('Dates', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Filing Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_filingDate ?? 'Select date'),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.caseId != null ? 'Update Case' : 'Create Case'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClientPicker(List<ClientModel> clients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ClientPickerSheet(
        clients: clients,
        searchCtrl: _clientSearchCtrl,
        onSelected: (client) {
          setState(() {
            _selectedClientId = client.id;
            _selectedClientName = client.name;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final List<ClientModel> clients;
  final TextEditingController searchCtrl;
  final ValueChanged<ClientModel> onSelected;

  const _ClientPickerSheet({
    required this.clients,
    required this.searchCtrl,
    required this.onSelected,
  });

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  List<ClientModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.clients;
    widget.searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_filter);
    super.dispose();
  }

  void _filter() {
    final q = widget.searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = widget.clients
          .where((c) => c.name.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search clients...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: _filtered.isEmpty
                ? const Center(child: Text('No clients found'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(c.name[0])),
                        title: Text(c.name),
                        subtitle: Text(c.email ?? c.phone ?? ''),
                        onTap: () => widget.onSelected(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
