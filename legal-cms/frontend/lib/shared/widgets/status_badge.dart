import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_display, style: TextStyle(fontSize: fontSize, color: Colors.white)),
      backgroundColor: _color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String get _display {
    switch (status.toUpperCase()) {
      case 'ACTIVE': return 'Active';
      case 'PENDING': return 'Pending';
      case 'CLOSED': return 'Closed';
      case 'ADJOURNED': return 'Adjourned';
      case 'SCHEDULED': return 'Scheduled';
      case 'COMPLETED': return 'Completed';
      case 'CANCELLED': return 'Cancelled';
      default: return status;
    }
  }

  Color get _color {
    switch (status.toUpperCase()) {
      case 'ACTIVE': return AppColors.secondary;
      case 'PENDING': return AppColors.warning;
      case 'CLOSED': return AppColors.success;
      case 'ADJOURNED': return AppColors.accent;
      case 'SCHEDULED': return AppColors.secondary;
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      default: return Colors.grey;
    }
  }
}
