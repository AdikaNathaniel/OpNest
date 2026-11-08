import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/opportunity.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpportunityApi {
  OpportunityApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Fetches every live listing. Filtering happens in the app so that
  /// switching filters is instant; the full list is small.
  Future<OpportunityList> fetchAll() async {
    final uri = Uri.parse('$baseUrl/opportunities?status=all');
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException(
        "Couldn't reach the OpNest server at $baseUrl. Is the backend running?",
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'The server returned an error (${response.statusCode}).',
      );
    }
    return OpportunityList.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
