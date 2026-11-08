import 'package:flutter/material.dart';

import '../models/opportunity.dart';
import '../theme.dart';

class DeadlineBadge extends StatelessWidget {
  const DeadlineBadge({super.key, required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final days = opportunity.daysLeft;
    final colors = UrgencyColors.of(context, daysLeft: days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(days), size: 14, color: colors.foreground),
          const SizedBox(width: 4),
          Text(
            deadlineLabel(days),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(int? days) {
    if (days == null) return Icons.help_outline;
    if (days < 0) return Icons.lock_clock;
    return Icons.schedule;
  }
}

String deadlineLabel(int? days) {
  if (days == null) return 'No deadline stated';
  if (days < 0) return 'Closed';
  if (days == 0) return 'Closes today';
  if (days == 1) return '1 day left';
  return '$days days left';
}
