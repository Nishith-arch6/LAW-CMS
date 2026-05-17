import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/case_model.dart';
import '../../core/theme/app_theme.dart';
import 'status_badge.dart';

class CaseCard extends StatefulWidget {
  final CaseModel c;

  const CaseCard({super.key, required this.c});

  @override
  State<CaseCard> createState() => _CaseCardState();
}

class _CaseCardState extends State<CaseCard> {
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
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: _hovered ? 3 : 1,
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
                            StatusBadge(status: widget.c.status),
                            const SizedBox(width: 8),
                            Text(widget.c.caseNumber, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(widget.c.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (widget.c.clientName != null)
                          Text(widget.c.clientName!, style: theme.textTheme.bodySmall),
                        if (widget.c.nextHearingDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 14, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Text('Next: ${widget.c.nextHearingDate}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
