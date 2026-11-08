import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opnest/api/opportunity_api.dart';
import 'package:opnest/main.dart';

Map<String, dynamic> _opportunity(
  int id,
  String title, {
  required String status,
  int? daysLeft,
  List<String> levels = const ['Masters'],
}) => {
  'id': id,
  'title': title,
  'country': 'Sweden',
  'deadline': daysLeft == null ? null : '2026-12-01',
  'deadlineText': null,
  'levels': levels,
  'summary': 'Summary for $title.',
  'description': 'Eligibility\n• MPhil students\nPlease apply.',
  'emails': ['sacip@ug.edu.gh'],
  'links': <Object>[],
  'sourceUrl': 'https://ipo.ug.edu.gh/study-abroad/exchange-opportunities',
  'position': id,
  'firstSeenAt': DateTime.now().toIso8601String(),
  'lastSeenAt': DateTime.now().toIso8601String(),
  'removedAt': null,
  'notifiedAt': null,
  'status': status,
  'daysLeft': daysLeft,
  'isNew': id == 1,
};

OpportunityApi _api(http.Client client) =>
    OpportunityApi(baseUrl: 'http://test', client: client);

void main() {
  // A tall phone-sized screen, so the whole list is laid out.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(430, 2000);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  final listing = {
    'items': [
      _opportunity(1, 'Uppsala University', status: 'open', daysLeft: 20),
      _opportunity(2, 'Lund University', status: 'closed', daysLeft: -5),
      _opportunity(
        3,
        'Tokyo University',
        status: 'unknown',
        levels: ['Undergraduate'],
      ),
    ],
    'count': 3,
    'lastSyncedAt': DateTime.now().toIso8601String(),
  };
  final okClient = MockClient(
    // Bytes, not a String: http.Response encodes strings as Latin-1, which
    // can't represent the "•" in the descriptions.
    (_) async => http.Response.bytes(utf8.encode(jsonEncode(listing)), 200),
  );

  testWidgets('shows open opportunities and filters them', (tester) async {
    await tester.pumpWidget(OpNestApp(api: _api(okClient)));
    await tester.pumpAndSettle();

    // Open view: open plus no-deadline listings, closed one hidden.
    expect(find.text('Uppsala University'), findsOneWidget);
    expect(find.text('Tokyo University'), findsOneWidget);
    expect(find.text('Lund University'), findsNothing);
    expect(find.text('20 days left'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);

    await tester.tap(find.text('Closed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Lund University'), findsOneWidget);
    expect(find.text('Uppsala University'), findsNothing);

    await tester.tap(find.text('All (3)'));
    await tester.tap(find.widgetWithText(FilterChip, 'Undergraduate'));
    await tester.pumpAndSettle();
    expect(find.text('Tokyo University'), findsOneWidget);
    expect(find.text('Uppsala University'), findsNothing);
  });

  testWidgets('opens the detail screen', (tester) async {
    await tester.pumpWidget(OpNestApp(api: _api(okClient)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Uppsala University'));
    await tester.pumpAndSettle();

    expect(find.text('Opportunity'), findsOneWidget);
    expect(find.text('Eligibility'), findsOneWidget);
    expect(find.text('MPhil students'), findsOneWidget);
    expect(find.text('sacip@ug.edu.gh'), findsOneWidget);
  });

  testWidgets('shows an error with retry when the server is down', (
    tester,
  ) async {
    final failing = MockClient((_) async => throw Exception('offline'));
    await tester.pumpWidget(OpNestApp(api: _api(failing)));
    await tester.pumpAndSettle();

    expect(find.text('Could not load opportunities'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
