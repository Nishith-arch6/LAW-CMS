import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/case_model.dart';
import '../../core/theme/app_theme.dart';
import 'status_badge.dart';

class CaseCard extends StatelessWidget {
  final CaseModel c;

  const CaseCard({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/cases/${c.id}'),
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
                        StatusBadge(status: c.status),
                        const SizedBox(width: 8),
                        Text(c.caseNumber, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (c.clientName != null)
                      Text(c.clientName!, style: theme.textTheme.bodySmall),
                    if (c.nextHearingDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text('Next: ${c.nextHearingDate}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent)),
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
    );
  }
}
