import 'package:flutter/material.dart';

import '../api/opportunity_api.dart';
import '../models/opportunity.dart';
import '../widgets/opportunity_card.dart';
import 'detail_screen.dart';

enum StatusFilter { open, closed, all }

const _levels = ['Undergraduate', 'Masters', 'PhD'];
const _maxContentWidth = 820.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final OpportunityApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Opportunity>? _items;
  DateTime? _lastSyncedAt;
  String? _error;
  bool _loading = false;

  StatusFilter _status = StatusFilter.open;
  String? _level;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _lastSyncedAt = result.lastSyncedAt;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesStatus(Opportunity o, StatusFilter status) => switch (status) {
    StatusFilter.open => o.mayBeOpen,
    StatusFilter.closed => o.status == OpportunityStatus.closed,
    StatusFilter.all => true,
  };

  List<Opportunity> get _visible {
    final q = _query.trim().toLowerCase();
    final result = (_items ?? []).where((o) {
      if (!_matchesStatus(o, _status)) return false;
      if (_level != null && !o.levels.contains(_level)) return false;
      if (q.isEmpty) return true;
      return o.title.toLowerCase().contains(q) ||
          (o.country?.toLowerCase().contains(q) ?? false) ||
          o.description.toLowerCase().contains(q);
    }).toList();
    // Open listings: soonest deadline first, unstated deadlines last.
    // Otherwise keep the server's newest-first order.
    if (_status == StatusFilter.open) {
      result.sort(
        (a, b) => (a.daysLeft ?? 1 << 30).compareTo(b.daysLeft ?? 1 << 30),
      );
    }
    return result;
  }

  int _count(StatusFilter status) =>
      (_items ?? []).where((o) => _matchesStatus(o, status)).length;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sidePadding = width > _maxContentWidth + 32
        ? (width - _maxContentWidth) / 2
        : 16.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 72,
              // Line the title and actions up with the centered content.
              titleSpacing: sidePadding,
              title: Text(
                'OpNest',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
                SizedBox(width: sidePadding - 8),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              sliver: SliverToBoxAdapter(child: _buildIntroAndFilters(context)),
            ),
            ..._buildBody(context, sidePadding),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroAndFilters(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study-abroad and exchange opportunities from the University of Ghana '
          'International Programmes Office.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_lastSyncedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Updated ${_relativeTime(_lastSyncedAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SearchBar(
          // SearchBar caps itself at 800px wide unless told otherwise.
          constraints: const BoxConstraints(minHeight: 56),
          hintText: 'Search university, country or keyword',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(
            theme.colorScheme.surfaceContainerLowest,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<StatusFilter>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: StatusFilter.open,
                label: Text('Open (${_count(StatusFilter.open)})'),
              ),
              ButtonSegment(
                value: StatusFilter.closed,
                label: Text('Closed (${_count(StatusFilter.closed)})'),
              ),
              ButtonSegment(
                value: StatusFilter.all,
                label: Text('All (${_count(StatusFilter.all)})'),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in _levels)
              FilterChip(
                label: Text(level),
                selected: _level == level,
                onSelected: (on) => setState(() => _level = on ? level : null),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Widget> _buildBody(BuildContext context, double sidePadding) {
    if (_items == null && _loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_items == null && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            icon: Icons.cloud_off,
            title: 'Could not load opportunities',
            body: _error!,
            action: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            icon: Icons.travel_explore,
            title:
                _status == StatusFilter.open && _query.isEmpty && _level == null
                ? 'No open opportunities right now'
                : 'Nothing matches your filters',
            body: _status == StatusFilter.open
                ? 'New postings appear here as soon as the IPO publishes them. '
                      'Check "All" to browse past calls.'
                : 'Try a different search or clear the filters.',
            action: OutlinedButton(
              onPressed: () => setState(() {
                _status = StatusFilter.all;
                _level = null;
              }),
              child: const Text('Show all opportunities'),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 32),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => OpportunityCard(
            opportunity: visible[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DetailScreen(opportunity: visible[i]),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
