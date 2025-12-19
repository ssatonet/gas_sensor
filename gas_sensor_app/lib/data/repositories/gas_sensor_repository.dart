import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_sensor_app/data/models/models.dart';

class GasSensorRepository {
  final SupabaseClient _client;
  final SharedPreferences? _prefs;

  GasSensorRepository(this._client, [this._prefs]);

  Stream<List<SiteModel>> getSitesStream() async* {
    final prefs = _prefs;
    // 1. Emit cache immediately
    if (prefs != null) {
      final cached = prefs.getString('cache_sites');
      if (cached != null) {
        try {
          final List decoded = jsonDecode(cached);
          yield decoded.map((e) => SiteModel.fromJson(e)).toList();
        } catch (_) {}
      }
    }

    // 2. Fetch from network
    try {
      final response = await _client.from('sites').select();
      final data = (response as List).map((e) => SiteModel.fromJson(e)).toList();

      // Update cache
      if (prefs != null) {
        prefs.setString('cache_sites', jsonEncode(data.map((e) => e.toJson()).toList()));
      }
      yield data;
    } catch (e) {
      // If network fails and we haven't emitted cache yet (or even if we have),
      // we might want to rethrow if we have NO data?
      // Since we yielded cache above, the stream stays open? No, async* closes.
      // If we yielded cache, the user sees cache. If network fails, we can either:
      // - throw (Stream error) -> User sees error snackbar?
      // - just finish (User sees stale cache)
      
      // If we have cache, suppressing error is often preferred for "Offline mode".
      // But maybe we want to know? 
      // Let's rethrow only if no cache was emitted? Hard to know here.
      
      // Simple SWR:
      // yield Cache
      // yield Network (or throw)
      rethrow;
    }
  }

  Stream<List<EquipmentModel>> getEquipmentsStream(String siteId) async* {
    final prefs = _prefs;
    final cacheKey = 'cache_equipments_$siteId';
    
    // 1. Emit cache
    if (prefs != null) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        try {
          final List decoded = jsonDecode(cached);
          yield decoded.map((e) => EquipmentModel.fromJson(e)).toList();
        } catch (_) {}
      }
    }

    // 2. Fetch network
    try {
      final response = await _client
          .from('equipments')
          .select()
          .eq('site_id', siteId);
      final data = (response as List).map((e) => EquipmentModel.fromJson(e)).toList();
      
      if (prefs != null) {
        prefs.setString(cacheKey, jsonEncode(data.map((e) => e.toJson()).toList()));
      }
      yield data;
    } catch (e) {
      rethrow;
    }
  }

  
  Future<EquipmentModel?> getEquipmentByTag(String tagNo) async {
    final response = await _client
        .from('equipments')
        .select()
        .eq('tag_no', tagNo)
        .maybeSingle();
    
    if (response == null) return null;
    return EquipmentModel.fromJson(response);
  }

  Future<List<InspectionModel>> getInspections(String equipmentId) async {
    final response = await _client
        .from('inspections')
        .select()
        .eq('equipment_id', equipmentId)
        .order('inspection_date', ascending: false);
    return (response as List).map((e) => InspectionModel.fromJson(e)).toList();
  }

  Future<void> addInspection(InspectionModel inspection) async {
    await _client.from('inspections').insert(inspection.toJson());
  }

  Future<void> deleteInspection(String id) async {
    await _client.from('inspections').delete().eq('id', id);
  }
  
  // Call the SQL function for prediction
  Future<Map<String, dynamic>?> predictSensorLife(String equipmentId) async {
    try {
      final response = await _client.rpc('predict_sensor_life', params: {
        'target_equipment_id': equipmentId,
        'threshold': 60.0,
      });
      
      // RPC returns a list of rows, we expect one row
      if (response is List && response.isNotEmpty) {
        return response.first as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      // print('Prediction error: $e');
      return null;
    }
  }
}
