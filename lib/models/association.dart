class Association {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final String? logoUrl;
  final String? bannerUrl;
  final String? instagramUrl;

  /// Rempli quand la requête inclut `memberships(count)` (liste / détail).
  final int? memberCount;

  const Association({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.logoUrl,
    this.bannerUrl,
    this.instagramUrl,
    this.memberCount,
  });

  static int? _parseMemberCountFromJson(Map<String, dynamic> json) {
    final raw = json['memberships'];
    if (raw is! List || raw.isEmpty) return null;
    final first = raw.first;
    if (first is! Map) return null;
    final c = first['count'];
    if (c == null) return null;
    if (c is int) return c;
    if (c is num) return c.toInt();
    return null;
  }

  factory Association.fromJson(Map<String, dynamic> json) {
    return Association(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime(2000),
      logoUrl: json['logo_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      memberCount: _parseMemberCountFromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'instagram_url': instagramUrl,
    };
  }

  Association copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    String? logoUrl,
    String? bannerUrl,
    String? instagramUrl,
    int? memberCount,
  }) {
    return Association(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}
