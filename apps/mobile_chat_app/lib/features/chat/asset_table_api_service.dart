import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/llm_config_service.dart';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

class AssetTableColumn {
  const AssetTableColumn({
    required this.id,
    required this.resourceId,
    required this.columnKey,
    required this.displayName,
    required this.columnOrder,
  });

  final String id;
  final String resourceId;
  final String columnKey;
  final String displayName;
  final int columnOrder;

  factory AssetTableColumn.fromJson(Map<String, dynamic> json) {
    return AssetTableColumn(
      id: json['id'] as String,
      resourceId: json['resourceId'] as String,
      columnKey: json['columnKey'] as String,
      displayName: json['displayName'] as String,
      columnOrder: (json['columnOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class AssetTableRow {
  const AssetTableRow({
    required this.id,
    required this.resourceId,
    required this.displayNumber,
    required this.cellData,
  });

  final String id;
  final String resourceId;
  final int displayNumber;
  final Map<String, String?> cellData;

  factory AssetTableRow.fromJson(Map<String, dynamic> json) {
    final raw = json['cellData'] as Map<String, dynamic>? ?? {};
    return AssetTableRow(
      id: json['id'] as String,
      resourceId: json['resourceId'] as String,
      displayNumber: (json['displayNumber'] as num?)?.toInt() ?? 0,
      cellData: raw.map(
        (k, v) => MapEntry(k, v as String?),
      ),
    );
  }
}

class AssetTableDetail {
  const AssetTableDetail({
    required this.id,
    required this.resourceId,
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String id;
  final String resourceId;
  final String title;
  final List<AssetTableColumn> columns;
  final List<AssetTableRow> rows;

  factory AssetTableDetail.fromJson(Map<String, dynamic> json) {
    return AssetTableDetail(
      id: json['id'] as String,
      resourceId: json['resourceId'] as String,
      title: json['title'] as String,
      columns: (json['columns'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AssetTableColumn.fromJson)
          .toList(),
      rows: (json['rows'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AssetTableRow.fromJson)
          .toList(),
    );
  }
}

class AssetTableSummary {
  const AssetTableSummary({
    required this.id,
    required this.resourceId,
    required this.title,
  });

  final String id;
  final String resourceId;
  final String title;

  factory AssetTableSummary.fromJson(Map<String, dynamic> json) {
    return AssetTableSummary(
      id: json['id'] as String,
      resourceId: json['resourceId'] as String,
      title: json['title'] as String,
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class AssetTableApiService {
  AssetTableApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  String get _base => LlmConfigService.resolveBaseUrl();
  Uri get _tablesUri => Uri.parse('$_base/api/resources/tables');
  Uri _tableUri(String resourceId) =>
      Uri.parse('$_base/api/resources/tables/${Uri.encodeComponent(resourceId)}');
  Uri _columnsUri(String resourceId) =>
      Uri.parse('$_base/api/resources/tables/${Uri.encodeComponent(resourceId)}/columns');
  Uri _columnUri(String resourceId, String columnKey) => Uri.parse(
        '$_base/api/resources/tables/${Uri.encodeComponent(resourceId)}/columns/${Uri.encodeComponent(columnKey)}',
      );
  Uri _rowsUri(String resourceId) =>
      Uri.parse('$_base/api/resources/tables/${Uri.encodeComponent(resourceId)}/rows');
  Uri _rowUri(String resourceId, String rowId) => Uri.parse(
        '$_base/api/resources/tables/${Uri.encodeComponent(resourceId)}/rows/${Uri.encodeComponent(rowId)}',
      );

  Future<List<AssetTableSummary>> listTables({required String token}) async {
    final response = await _httpClient.get(
      _tablesUri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to list tables: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['tables'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AssetTableSummary.fromJson)
        .toList();
  }

  Future<AssetTableDetail> getTable({
    required String token,
    required String resourceId,
  }) async {
    final response = await _httpClient.get(
      _tableUri(resourceId),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get table: ${response.statusCode}');
    }
    return AssetTableDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AssetTableSummary> createTable({
    required String token,
    required String resourceId,
    required String title,
  }) async {
    final response = await _httpClient.post(
      _tablesUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'resourceId': resourceId, 'title': title}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create table: ${response.statusCode}');
    }
    return AssetTableSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AssetTableColumn> addColumn({
    required String token,
    required String resourceId,
    required String columnKey,
    required String displayName,
    int columnOrder = 0,
  }) async {
    final response = await _httpClient.post(
      _columnsUri(resourceId),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'columnKey': columnKey,
        'displayName': displayName,
        'columnOrder': columnOrder,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add column: ${response.statusCode}');
    }
    return AssetTableColumn.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> removeColumn({
    required String token,
    required String resourceId,
    required String columnKey,
  }) async {
    final response = await _httpClient.delete(
      _columnUri(resourceId, columnKey),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove column: ${response.statusCode}');
    }
  }

  Future<AssetTableRow> addRow({
    required String token,
    required String resourceId,
    Map<String, String?> cellData = const {},
  }) async {
    final response = await _httpClient.post(
      _rowsUri(resourceId),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'cellData': cellData}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add row: ${response.statusCode}');
    }
    return AssetTableRow.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AssetTableRow> updateRow({
    required String token,
    required String resourceId,
    required String rowId,
    required Map<String, String?> cellData,
  }) async {
    final response = await _httpClient.patch(
      _rowUri(resourceId, rowId),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'cellData': cellData}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update row: ${response.statusCode}');
    }
    return AssetTableRow.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteRow({
    required String token,
    required String resourceId,
    required String rowId,
  }) async {
    final response = await _httpClient.delete(
      _rowUri(resourceId, rowId),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete row: ${response.statusCode}');
    }
  }
}
