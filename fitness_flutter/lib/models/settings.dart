class AppSettings {
  final String weightUnit;
  final String? aiProvider;
  final String? aiModel;
  final bool aiApiKeySet;
  final String? aiEndpoint;
  final bool scholarSearchEnabled;

  const AppSettings({
    this.weightUnit = 'kg',
    this.aiProvider,
    this.aiModel,
    this.aiApiKeySet = false,
    this.aiEndpoint,
    this.scholarSearchEnabled = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    weightUnit: json['weight_unit'] as String? ?? 'kg',
    aiProvider: json['ai_provider'] as String?,
    aiModel: json['ai_model'] as String?,
    aiApiKeySet: json['ai_api_key_set'] as bool? ?? false,
    aiEndpoint: json['ai_endpoint'] as String?,
    scholarSearchEnabled: json['scholar_search_enabled'] as bool? ?? false,
  );
}
