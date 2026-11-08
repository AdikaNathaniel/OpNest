import 'package:flutter/material.dart';

import 'api/opportunity_api.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(OpNestApp(api: OpportunityApi(baseUrl: apiBaseUrl)));
}

class OpNestApp extends StatelessWidget {
  const OpNestApp({super.key, required this.api});

  final OpportunityApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpNest',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(api: api),
    );
  }
}
