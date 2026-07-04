class CoachSource {
  final String id;
  final String title;
  final String kind;
  final String? url;
  final int? year;

  const CoachSource({
    required this.id,
    required this.title,
    required this.kind,
    this.url,
    this.year,
  });

  factory CoachSource.fromJson(Map<String, dynamic> json) => CoachSource(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    url: json['url'] as String?,
    year: json['year'] as int?,
  );
}

class CoachMessage {
  final String role;
  final String content;
  final List<CoachSource>? sources;
  final DateTime? timestamp;

  const CoachMessage({
    required this.role,
    required this.content,
    this.sources,
    this.timestamp,
  });

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
    role: json['role'] as String? ?? 'assistant',
    content: json['content'] as String? ?? '',
    sources: (json['sources'] as List?)
        ?.map((s) => CoachSource.fromJson(s as Map<String, dynamic>))
        .toList(),
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
  );
}
