import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/opportunity.dart';
import 'deadline_badge.dart';

final _dateFormat = DateFormat('d MMM yyyy');

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.opportunity, this.onTap});

  final Opportunity opportunity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = opportunity;
    final closed = o.status == OpportunityStatus.closed;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: closed ? 0.7 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DeadlineBadge(opportunity: o),
                    const Spacer(),
                    if (o.isNew) const _NewBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  o.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (o.country != null)
                      _Meta(icon: Icons.place_outlined, text: o.country!),
                    if (o.deadline != null)
                      _Meta(
                        icon: Icons.event_outlined,
                        text: 'Apply by ${_dateFormat.format(o.deadline!)}',
                      ),
                  ],
                ),
                if (o.summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    o.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                if (o.levels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final l in o.levels) LevelTag(level: l)],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LevelTag extends StatelessWidget {
  const LevelTag({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'NEW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onTertiary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
