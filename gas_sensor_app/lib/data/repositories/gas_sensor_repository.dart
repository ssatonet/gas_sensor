import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_sensor_app/data/models/models.dart';

class GasSensorRepository {
  final SupabaseClient _client;

  GasSensorRepository(this._client);

  Future<List<SiteModel>> getSites() async {
    final response = await _client.from('sites').select();
    return (response as List).map((e) => SiteModel.fromJson(e)).toList();
  }

  Future<List<EquipmentModel>> getEquipments(String siteId) async {
    final response = await _client
        .from('equipments')
        .select()
        .eq('site_id', siteId);
    return (response as List).map((e) => EquipmentModel.fromJson(e)).toList();
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
