import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_sensor_app/data/repositories/gas_sensor_repository.dart';
import 'package:gas_sensor_app/data/models/models.dart';

// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Repository Provider
final gasSensorRepositoryProvider = Provider<GasSensorRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider); // This might throw unimplemented initially if not overridden, but we override in main.
  // Ideally, use a safe way or ensuring initialization. main.dart does overrides.
  return GasSensorRepository(client, prefs);
});

// StreamProvider to fetch sites (SWR)
final sitesProvider = StreamProvider((ref) {
  final repository = ref.watch(gasSensorRepositoryProvider);
  return repository.getSitesStream();
});

// Notifier for selected Site ID


// Shared Preferences Provider (Overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// Notifier for selected Site ID with Persistence
class SelectedSiteId extends Notifier<String?> {
  static const _key = 'selected_site_id';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key);
  }
  
  void set(String? id) {
    state = id;
    final prefs = ref.read(sharedPreferencesProvider);
    if (id != null) {
      prefs.setString(_key, id);
    } else {
      prefs.remove(_key);
    }
  }
}

final selectedSiteIdProvider = NotifierProvider<SelectedSiteId, String?>(SelectedSiteId.new);

// StreamProvider to fetch equipments for selected site
final equipmentsProvider = StreamProvider((ref) {
  final repository = ref.watch(gasSensorRepositoryProvider);
  final siteId = ref.watch(selectedSiteIdProvider);
  
  if (siteId == null) return const Stream.empty();
  return repository.getEquipmentsStream(siteId);
});

class EquipmentListItem {
  final EquipmentModel equipment;
  final InspectionModel? latestInspection;
  final Map<String, dynamic>? prediction;

  EquipmentListItem({
    required this.equipment,
    this.latestInspection,
    this.prediction,
  });
  
  int? get daysRemaining => prediction?['days_remaining'];
  double get sensitivity => latestInspection?.gasSensitivity ?? 0;
  
  // Danger Level: 0 = Critical, 1 = Warning, 2 = Normal
  int get dangerLevel {
    if (daysRemaining != null && daysRemaining! < 30) return 0;
    if (sensitivity > 0 && sensitivity < 50) return 0;
    if (sensitivity > 0 && sensitivity < 70) return 1;
    return 2;
  }
  
  String get result => latestInspection?.result ?? '-';
}

enum SortOption {
  danger, // 危険度順
  sensitivity, // 感度順
  daysRemaining, // 交換予測日順
  tagNo, // TAG No順
}

class EquipmentSort extends Notifier<SortOption> {
  static const _key = 'equipment_sort_option';

  @override
  SortOption build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final index = prefs.getInt(_key);
    if (index != null && index >= 0 && index < SortOption.values.length) {
      return SortOption.values[index];
    }
    return SortOption.tagNo;
  }
  
  void set(SortOption option) {
    state = option;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_key, option.index);
  }
}

final equipmentSortProvider = NotifierProvider<EquipmentSort, SortOption>(EquipmentSort.new);

// Fetch all equipments with status (SWR)
final siteEquipmentsProvider = StreamProvider<List<EquipmentListItem>>((ref) async* {
  final repository = ref.watch(gasSensorRepositoryProvider);
  final siteId = ref.watch(selectedSiteIdProvider);
  
  if (siteId == null) {
    yield [];
    return;
  }
  
  // Listen to the equipment stream (Cache -> Network)
  final equipmentStream = repository.getEquipmentsStream(siteId);
  
  await for (final equipments in equipmentStream) {
    final list = <EquipmentListItem>[];
    
    // For each equipment list emitted (cache then network), fetch details
    // Note: This fetches inspections N times. optimizing inspections fetching is separate task.
    for (final eq in equipments) {
      final inspections = await repository.getInspections(eq.id);
      InspectionModel? latest;
      Map<String, dynamic>? prediction;
      
      if (inspections.isNotEmpty) {
        latest = inspections.first;
        prediction = await repository.predictSensorLife(eq.id);
      }
      
      list.add(EquipmentListItem(
        equipment: eq,
        latestInspection: latest,
        prediction: prediction,
      ));
    }
    yield list;
  }
});
final sortedEquipmentsProvider = Provider<AsyncValue<List<EquipmentListItem>>>((ref) {
  final allAsync = ref.watch(siteEquipmentsProvider);
  final sortOption = ref.watch(equipmentSortProvider);
  
  return allAsync.whenData((list) {
    final sorted = List<EquipmentListItem>.from(list);
    sorted.sort((a, b) => _sortEquipments(a, b, sortOption));
    return sorted;
  });
});

int _sortEquipments(EquipmentListItem a, EquipmentListItem b, SortOption option) {
  switch (option) {
    case SortOption.sensitivity:
      // 0 (no data) should be last
      if (a.sensitivity == 0 && b.sensitivity == 0) return 0;
      if (a.sensitivity == 0) return 1;
      if (b.sensitivity == 0) return -1;
      return a.sensitivity.compareTo(b.sensitivity);
      
    case SortOption.daysRemaining:
      if (a.daysRemaining != null && b.daysRemaining != null) {
        return a.daysRemaining!.compareTo(b.daysRemaining!);
      }
      if (a.daysRemaining != null) return -1;
      if (b.daysRemaining != null) return 1;
      return 0;
      
    case SortOption.tagNo:
      return a.equipment.tagNo.compareTo(b.equipment.tagNo);
      
    case SortOption.danger:
      if (a.dangerLevel != b.dangerLevel) {
        return a.dangerLevel.compareTo(b.dangerLevel);
      }
      if (a.daysRemaining != null && b.daysRemaining != null) {
        return a.daysRemaining!.compareTo(b.daysRemaining!);
      }
      return a.sensitivity.compareTo(b.sensitivity);
  }
}

final inspectionsProvider = FutureProvider.family<List<InspectionModel>, String>((ref, equipmentId) async {
  final repository = ref.watch(gasSensorRepositoryProvider);
  return repository.getInspections(equipmentId);
});

final predictionProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, equipmentId) async {
  final repository = ref.watch(gasSensorRepositoryProvider);
  return repository.predictSensorLife(equipmentId);
});
