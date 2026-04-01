import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/association.dart';
import '../../../models/association_photo.dart';

class AssociationService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _bucketLogos = 'association-logos';
  static const _bucketBanners = 'association-banners';
  static const _bucketPhotos = 'association-photos';

  /// Colonnes + `memberships(count)` pour afficher le nombre de membres (liste / fiche).
  static const _selectWithMemberCount =
      'id, name, description, created_at, logo_url, banner_url, instagram_url, memberships(count)';

  // ─── Lecture ─────────────────────────────────────────────────────────────────

  Future<List<Association>> fetchAssociations() async {
    try {
      final data = await _client
          .from('associations')
          .select(_selectWithMemberCount)
          .order('name', ascending: true);

      return (data as List)
          .map((json) => Association.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<Association> fetchAssociationById(String id) async {
    try {
      final data = await _client
          .from('associations')
          .select(_selectWithMemberCount)
          .eq('id', id)
          .single();

      return Association.fromJson(data);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<List<AssociationPhoto>> fetchPhotos(String associationId) async {
    try {
      final data = await _client
          .from('association_photos')
          .select()
          .eq('association_id', associationId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((json) =>
              AssociationPhoto.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  // ─── Upload images ────────────────────────────────────────────────────────────

  Future<String> uploadLogo(
      String associationId, Uint8List bytes, String ext) async {
    try {
      final path = '$associationId/logo.${ext.isEmpty ? 'jpg' : ext}';
      await _client.storage.from(_bucketLogos).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                contentType: _mimeType(ext), upsert: true),
          );
      return _client.storage.from(_bucketLogos).getPublicUrl(path);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<String> uploadBanner(
      String associationId, Uint8List bytes, String ext) async {
    try {
      final path = '$associationId/banner.${ext.isEmpty ? 'jpg' : ext}';
      await _client.storage.from(_bucketBanners).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                contentType: _mimeType(ext), upsert: true),
          );
      return _client.storage.from(_bucketBanners).getPublicUrl(path);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<AssociationPhoto> addPhoto(
      String associationId, Uint8List bytes, String ext) async {
    try {
      final path =
          '$associationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from(_bucketPhotos).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: _mimeType(ext)),
          );
      final url =
          _client.storage.from(_bucketPhotos).getPublicUrl(path);

      final userId = _client.auth.currentUser?.id;
      final data = await _client
          .from('association_photos')
          .insert({
            'association_id': associationId,
            'photo_url': url,
            if (userId != null) 'uploaded_by': userId,
          })
          .select()
          .single();

      return AssociationPhoto.fromJson(data);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<void> deletePhoto(String photoId) async {
    try {
      await _client.from('association_photos').delete().eq('id', photoId);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  // ─── Création / Modification ──────────────────────────────────────────────────

  Future<Association> createAssociation({
    required String name,
    String? description,
  }) async {
    try {
      final data = await _client
          .from('associations')
          .insert({
            'name': name.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
          })
          .select()
          .single();

      return Association.fromJson(data);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<Association> updateAssociation({
    required String id,
    required String name,
    String? description,
    String? logoUrl,
    bool clearLogo = false,
    String? bannerUrl,
    bool clearBanner = false,
    String? instagramUrl,
  }) async {
    try {
      final data = await _client
          .from('associations')
          .update({
            'name': name.trim(),
            'description':
                (description != null && description.trim().isNotEmpty)
                    ? description.trim()
                    : null,
            if (clearLogo)
              'logo_url': null
            else if (logoUrl != null)
              'logo_url': logoUrl,
            if (clearBanner)
              'banner_url': null
            else if (bannerUrl != null)
              'banner_url': bannerUrl,
            'instagram_url':
                (instagramUrl != null && instagramUrl.trim().isNotEmpty)
                    ? instagramUrl.trim()
                    : null,
          })
          .eq('id', id)
          .select()
          .single();

      return Association.fromJson(data);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  Future<int> fetchMemberCount(String associationId) async {
    try {
      final data = await _client
          .from('memberships')
          .select()
          .eq('association_id', associationId);

      return (data as List).length;
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  static String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
