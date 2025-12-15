import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_sensor_app/data/providers.dart';
import 'package:gas_sensor_app/data/models/models.dart';

class SiteAnalysis {
  final int totalSensors;
  final int criticalCount;
  final int warningCount;
  final int passCount; // Includes "Normal" status
  final int unknownCount;
  final List<String> anomalies;
  final Map<String, double> modelAverageLife;
  final Map<int, int> replacementForecast; // 3, 6, 12 months

  SiteAnalysis({
    required this.totalSensors,
    required this.criticalCount,
    required this.warningCount,
    required this.passCount,
    required this.unknownCount,
    required this.anomalies,
    required this.modelAverageLife,
    required this.replacementForecast,
  });
}

final siteAnalysisProvider = FutureProvider<SiteAnalysis>((ref) async {
  final equipments = await ref.watch(siteEquipmentsProvider.future);
  
  int critical = 0;
  int warning = 0;
  int pass = 0;
  int unknown = 0;
  final anomalies = <String>[];
  final modelLifespans = <String, List<int>>{}; // Model -> List of days remaining
  final forecast = {3: 0, 6: 0, 12: 0};

  for (final item in equipments) {
    // 1. Unified Counting Logic
    // Priority: Explicit Result > Danger Level
    bool counted = false;
    
    if (item.result == '不合格') {
      critical++;
      counted = true;
    } else if (item.result == '合格') {
      pass++;
      counted = true;
    }
    
    if (!counted) {
      // Fallback to danger level
      if (item.dangerLevel == 0) {
        critical++;
      } else if (item.dangerLevel == 1) {
        warning++;
      } else if (item.dangerLevel == 2) {
        // If result is '-' but danger is Normal, treat as Pass/Normal
        pass++;
      } else {
        unknown++;
      }
    }

    // 2. Forecast & Model Stats
    if (item.daysRemaining != null) {
      // Only count positive remaining days for forecast
      if (item.daysRemaining! > 0) {
        if (item.daysRemaining! < 90) forecast[3] = (forecast[3] ?? 0) + 1;
        if (item.daysRemaining! < 180) forecast[6] = (forecast[6] ?? 0) + 1;
        if (item.daysRemaining! < 365) forecast[12] = (forecast[12] ?? 0) + 1;
      }
      
      // Collect data for model average (exclude extreme outliers > 10 years)
      if (item.equipment.modelName != null && item.daysRemaining! < 3650) {
        modelLifespans.putIfAbsent(item.equipment.modelName!, () => []).add(item.daysRemaining!);
      }
    }
    
    // 3. Anomaly Detection
    // Flag if Critical/Fail
    if (item.dangerLevel == 0 || item.result == '不合格') {
      anomalies.add('${item.equipment.tagNo} (${item.equipment.modelName}): Critical Status');
    }
  }

  // Calculate Model Averages
  final modelAverages = <String, double>{};
  modelLifespans.forEach((model, days) {
    if (days.isNotEmpty) {
      modelAverages[model] = days.reduce((a, b) => a + b) / days.length;
    }
  });

  return SiteAnalysis(
    totalSensors: equipments.length,
    criticalCount: critical,
    warningCount: warning,
    passCount: pass,
    unknownCount: unknown,
    anomalies: anomalies,
    modelAverageLife: modelAverages,
    replacementForecast: forecast,
  );
});

class EquipmentInspectionHistory {
  final EquipmentModel equipment;
  final List<InspectionModel> inspections;
  EquipmentInspectionHistory(this.equipment, this.inspections);
}

final siteInspectionsProvider = FutureProvider<List<EquipmentInspectionHistory>>((ref) async {
  final repository = ref.watch(gasSensorRepositoryProvider);
  final siteId = ref.watch(selectedSiteIdProvider);
  if (siteId == null) return [];

  final equipments = await ref.watch(siteEquipmentsProvider.future);
  final result = <EquipmentInspectionHistory>[];

  for (final eq in equipments) {
    final inspections = await repository.getInspections(eq.equipment.id);
    if (inspections.isNotEmpty) {
      // Sort by date ascending
      inspections.sort((a, b) => a.inspectionDate.compareTo(b.inspectionDate));
      result.add(EquipmentInspectionHistory(eq.equipment, inspections));
    }
  }
  return result;
});
