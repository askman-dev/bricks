import 'dart:convert';

import '../../services/authenticated_api_client.dart';
import '../settings/llm_config_service.dart';

enum SitePublishState {
  notPublished,
  published,
  updateAvailable,
  publishFailed,
}

SitePublishState sitePublishStateFromApi(String? value) {
  switch (value) {
    case 'published':
      return SitePublishState.published;
    case 'update_available':
      return SitePublishState.updateAvailable;
    case 'publish_failed':
      return SitePublishState.publishFailed;
    case 'not_published':
    default:
      return SitePublishState.notPublished;
  }
}

class SitePublishStatus {
  const SitePublishStatus({
    required this.state,
    required this.publicUrl,
    this.latestBuildAt,
    this.currentCommitSha,
    this.publishedCommitSha,
    this.hasUnpublishedChanges = false,
  });

  final SitePublishState state;
  final String publicUrl;
  final DateTime? latestBuildAt;
  final String? currentCommitSha;
  final String? publishedCommitSha;
  final bool hasUnpublishedChanges;

  factory SitePublishStatus.fromJson(Map<String, dynamic> json) {
    final publish =
        Map<String, dynamic>.from((json['publish'] as Map?) ?? const {});
    final site = Map<String, dynamic>.from((json['site'] as Map?) ?? const {});
    return SitePublishStatus(
      state: sitePublishStateFromApi(publish['state'] as String?),
      publicUrl: (publish['publicUrl'] as String?) ??
          (site['publicUrl'] as String?) ??
          '',
      latestBuildAt:
          DateTime.tryParse((publish['latestBuildAt'] as String?) ?? ''),
      currentCommitSha: publish['currentCommitSha'] as String?,
      publishedCommitSha: publish['publishedCommitSha'] as String?,
      hasUnpublishedChanges: publish['hasUnpublishedChanges'] == true,
    );
  }
}

class SitePublishApiService {
  SitePublishApiService({AuthenticatedApiClient? apiClient})
      : _apiClient = apiClient ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _apiClient;

  Future<SitePublishStatus> fetchStatus(String channelId) async {
    final encoded = Uri.encodeComponent(channelId);
    final response = await _apiClient.get(
      Uri.parse(
          '${LlmConfigService.resolveBaseUrl()}/api/sites/$encoded/publish-status'),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load site publish status (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid site publish status response');
    }
    return SitePublishStatus.fromJson(Map<String, dynamic>.from(decoded));
  }
}
