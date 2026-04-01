class AssociationPhoto {
  final String id;
  final String associationId;
  final String photoUrl;
  final String? uploadedBy;
  final DateTime createdAt;

  const AssociationPhoto({
    required this.id,
    required this.associationId,
    required this.photoUrl,
    this.uploadedBy,
    required this.createdAt,
  });

  factory AssociationPhoto.fromJson(Map<String, dynamic> json) {
    return AssociationPhoto(
      id: json['id'] as String,
      associationId: json['association_id'] as String,
      photoUrl: json['photo_url'] as String,
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime(2000),
    );
  }
}
