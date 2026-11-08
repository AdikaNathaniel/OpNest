import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/opportunity.dart';
import '../widgets/deadline_badge.dart';
import '../widgets/opportunity_card.dart';

final _dateFormat = DateFormat('EEEE, d MMMM yyyy');

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.opportunity});

  final Opportunity opportunity;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't open $uri")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = opportunity;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Opportunity')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  o.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DeadlineBadge(opportunity: o),
                ),
                const SizedBox(height: 16),
                _FactsCard(opportunity: o),
                const SizedBox(height: 24),
                Text('Details', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _Description(text: o.description),
                if (o.emails.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Contacts', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final email in o.emails)
                        ActionChip(
                          avatar: const Icon(Icons.mail_outline, size: 18),
                          label: Text(email),
                          onPressed: () => _open(
                            context,
                            Uri(
                              scheme: 'mailto',
                              path: email,
                              query:
                                  'subject=${Uri.encodeComponent('Enquiry: ${o.title}')}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (o.links.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Links', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  for (final link in o.links)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link),
                      title: Text(
                        link.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        Uri.tryParse(link.url)?.host ?? link.url,
                        maxLines: 1,
                      ),
                      onTap: () => _open(context, Uri.parse(link.url)),
                    ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _open(context, Uri.parse(o.sourceUrl)),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View on the UG IPO website'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Details are extracted automatically. Confirm dates and '
                  'requirements on the original page before applying.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final o = opportunity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _Fact(
              icon: Icons.place_outlined,
              label: 'Country',
              child: Text(o.country ?? 'Not stated'),
            ),
            _Fact(
              icon: Icons.event_outlined,
              label: 'Deadline',
              child: Text(
                o.deadline == null
                    ? 'Not stated'
                    : _dateFormat.format(o.deadline!),
              ),
            ),
            _Fact(
              icon: Icons.school_outlined,
              label: 'Level',
              child: o.levels.isEmpty
                  ? const Text('Not stated')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final l in o.levels) LevelTag(level: l)],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w600),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the scraped description: bullet and numbered lines become list
/// rows, short label-like lines ("Eligibility", "Programmes") become headings.
class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String text;

  static final _bullet = RegExp(r'^(•|\d+\.)\s*');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.5);
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            if (_bullet.hasMatch(line))
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        line.startsWith('•')
                            ? '•'
                            : _bullet.firstMatch(line)!.group(1)!,
                        style: body?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                    Expanded(
                      child: Text(line.replaceFirst(_bullet, ''), style: body),
                    ),
                  ],
                ),
              )
            else if (_isHeading(line))
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  line.replaceAll(RegExp(r':$'), ''),
                  style: theme.textTheme.titleSmall,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(line, style: body),
              ),
        ],
      ),
    );
  }

  static bool _isHeading(String line) =>
      line.length <= 40 && !line.endsWith('.') && !line.contains('@');
}
