import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../../core/config/supabase.dart';

final companyDataRepositoryProvider =
    Provider<CompanyDataRepository>((_) => CompanyDataRepository());

class CompanyDataRepository {
  Future<Map<String, dynamic>> createCompany({
    required String ownerUserId,
    required String name,
    String? contactPhone,
    String? description,
    required String city,
  }) async {
    return await supabase.from('companies').insert({
      'owner_user_id': ownerUserId,
      'name': name,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (description != null) 'description': description,
      'city': city,
      'governorate': city,
      'verification_status': 'pending',
    }).select('id').single();
  }

  Future<void> promoteToOwner(String uid) async {
    await supabase
        .from('profiles')
        .update({'role': 'owner'})
        .eq('id', uid)
        .eq('role', 'customer');
  }

  Future<void> uploadCompanyDocument({
    required String uid,
    required String companyId,
    required String remotePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await supabase.storage.from('company-docs').uploadBinary(
          remotePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  Future<void> appendDocumentUrl(
      String companyId, String remotePath, String docType) async {
    final existing = await supabase
        .from('companies')
        .select('document_urls')
        .eq('id', companyId)
        .single();
    final urls =
        List<String>.from(existing['document_urls'] as List? ?? []);
    urls.removeWhere((u) => u.contains('/$docType'));
    urls.add(remotePath);
    await supabase
        .from('companies')
        .update({'document_urls': urls}).eq('id', companyId);
  }

  Future<Map<String, dynamic>?> fetchCompanyProfile(
      String companyId) async {
    return await supabase
        .from('companies')
        .select(
            'id, name, city, governorate, contact_phone, verification_status')
        .eq('id', companyId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchCompanyGenerators(
      String companyId) async {
    final data = await supabase
        .from('generators')
        .select(
            'id, title, capacity_kva, price_per_day, city, photos, avg_score, rating_count')
        .eq('company_id', companyId)
        .eq('status', 'available')
        .order('avg_score', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
