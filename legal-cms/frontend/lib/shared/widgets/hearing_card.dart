import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hearing_model.dart';
import '../../core/theme/app_theme.dart';
import 'status_badge.dart';

class HearingCard extends StatelessWidget {
  final HearingModel hearing;
  final VoidCallback? onTap;

  const HearingCard({super.key, required this.hearing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _formatDate(hearing.hearingDate);
    final timeStr = _formatTime(hearing.hearingTime);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gavel, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hearing.purpose ?? 'Hearing',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        StatusBadge(status: hearing.status, fontSize: 10),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hearing.caseTitle ?? 'Case #${hearing.caseId}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(timeStr, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        if (hearing.courtRoom != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.meeting_room, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(hearing.courtRoom!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        ],
                      ],
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

  String _formatDate(String d) {
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _formatTime(String? t) {
    if (t == null || t.length < 5) return '--:--';
    try {
      return t.substring(0, 5);
    } catch (_) {
      return '--:--';
    }
  }
}
