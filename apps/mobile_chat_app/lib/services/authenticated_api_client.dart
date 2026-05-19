import 'package:http/http.dart' as http;

import '../features/auth/auth_service.dart';

typedef AuthTokenProvider = Future<String?> Function();

class MissingAuthTokenException implements Exception {
  const MissingAuthTokenException();

  @override
  String toString() => 'MissingAuthTokenException';
}

class UnauthorizedApiException implements Exception {
  const UnauthorizedApiException(this.uri);

  final Uri uri;

  @override
  String toString() => 'UnauthorizedApiException: $uri';
}

class AuthenticatedApiClient {
  AuthenticatedApiClient({
    http.Client? httpClient,
    AuthTokenProvider? tokenProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider ?? AuthService.getToken;

  final http.Client _httpClient;
  final AuthTokenProvider _tokenProvider;

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _send(
      uri,
      headers: headers,
      sender: (authorizedHeaders) =>
          _httpClient.get(uri, headers: authorizedHeaders),
    );
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      uri,
      headers: headers,
      sender: (authorizedHeaders) =>
          _httpClient.post(uri, headers: authorizedHeaders, body: body),
    );
  }

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      uri,
      headers: headers,
      sender: (authorizedHeaders) =>
          _httpClient.delete(uri, headers: authorizedHeaders, body: body),
    );
  }

  Future<http.Response> _send(
    Uri uri, {
    required Future<http.Response> Function(Map<String, String> headers) sender,
    Map<String, String>? headers,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const MissingAuthTokenException();
    }
    final response = await sender({
      ...?headers,
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode == 401) {
      throw UnauthorizedApiException(uri);
    }
    return response;
  }
}
