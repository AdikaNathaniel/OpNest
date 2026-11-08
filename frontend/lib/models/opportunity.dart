enum OpportunityStatus { open, closed, unknown }

class OpportunityLink {
  const OpportunityLink({required this.text, required this.url});

  final String text;
  final String url;

  factory OpportunityLink.fromJson(Map<String, dynamic> json) =>
      OpportunityLink(text: json['text'] as String, url: json['url'] as String);
}

class Opportunity {
  const Opportunity({
    required this.id,
    required this.title,
    required this.country,
    required this.deadline,
    required this.deadlineText,
    required this.levels,
    required this.summary,
    required this.description,
    required this.emails,
    required this.links,
    required this.sourceUrl,
    required this.status,
    required this.daysLeft,
    required this.isNew,
    required this.firstSeenAt,
  });

  final int id;
  final String title;
  final String? country;
  final DateTime? deadline;
  final String? deadlineText;
  final List<String> levels;
  final String summary;
  final String description;
  final List<String> emails;
  final List<OpportunityLink> links;
  final String sourceUrl;
  final OpportunityStatus status;
  final int? daysLeft;
  final bool isNew;
  final DateTime firstSeenAt;

  /// Open, or with no stated deadline (so it may still be open).
  bool get mayBeOpen => status != OpportunityStatus.closed;

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'] as String?;
    return Opportunity(
      id: json['id'] as int,
      title: json['title'] as String,
      country: json['country'] as String?,
      deadline: deadline == null ? null : DateTime.parse(deadline),
      deadlineText: json['deadlineText'] as String?,
      levels: List<String>.from(json['levels'] as List),
      summary: json['summary'] as String? ?? '',
      description: json['description'] as String? ?? '',
      emails: List<String>.from(json['emails'] as List),
      links: (json['links'] as List)
          .map((l) => OpportunityLink.fromJson(l as Map<String, dynamic>))
          .toList(),
      sourceUrl: json['sourceUrl'] as String,
      status: OpportunityStatus.values.byName(json['status'] as String),
      daysLeft: json['daysLeft'] as int?,
      isNew: json['isNew'] as bool? ?? false,
      firstSeenAt: DateTime.parse(json['firstSeenAt'] as String),
    );
  }
}

class OpportunityList {
  const OpportunityList({required this.items, required this.lastSyncedAt});

  final List<Opportunity> items;
  final DateTime? lastSyncedAt;

  factory OpportunityList.fromJson(Map<String, dynamic> json) {
    final synced = json['lastSyncedAt'] as String?;
    return OpportunityList(
      items: (json['items'] as List)
          .map((o) => Opportunity.fromJson(o as Map<String, dynamic>))
          .toList(),
      lastSyncedAt: synced == null ? null : DateTime.parse(synced),
    );
  }
}
