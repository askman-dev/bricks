import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mock HTTP client for testing.
class MockHttpClient extends http.BaseClient {
  final Map<String, MockResponse> _responses = {};
  final List<http.Request> sentRequests = [];

  void addResponse(String url, MockResponse response) {
    _responses[url] = response;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sentRequests.add(request as http.Request);

    final response = _responses[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('Not found')),
        404,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class MockResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  MockResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}
