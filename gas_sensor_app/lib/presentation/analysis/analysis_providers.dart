import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_sensor_app/data/providers.dart';
import 'package:gas_sensor_app/data/models/models.dart';

class SiteAnalysisDetail {
  final String tagNo;
  final String modelName;
  final double sensitivity;
  final DateTime date;
  final String reason;

  SiteAnalysisDetail({
    required this.tagNo,
    required this.modelName,
    required this.sensitivity,
    required this.date,
    required this.reason,
  });
}

class SiteAnalysis {
  final int totalSensors;
  final int totalRecords; // Total inspection records
  final int criticalCount; // Current critical status count
  final int warningCount;
  final int passCount; 
  final int unknownCount;
  
  // Historical Record Stats
  final int totalPassRecords;
  final int totalFailRecords;

  final List<SiteAnalysisDetail> anomalies; // Detailed anomalies
  final Map<String, double> modelAverageLife;
  final Map<int, int> replacementForecast; // 3, 6 months
  
  // New Stats
  final Map<String, int> modelDistribution; // Model -> Count
  final Map<String, double> modelAverageSensitivity; // Model -> Avg Sensitivity (Latest)
  final double overallPassRate; 

  SiteAnalysis({
    required this.totalSensors,
    required this.totalRecords,
    required this.criticalCount,
    required this.warningCount,
    required this.passCount,
    required this.unknownCount,
    required this.totalPassRecords,
    required this.totalFailRecords,
    required this.anomalies,
    required this.modelAverageLife,
    required this.replacementForecast,
    required this.modelDistribution,
    required this.modelAverageSensitivity,
    required this.overallPassRate,
  });
}

final siteAnalysisProvider = FutureProvider<SiteAnalysis>((ref) async {
  final equipments = await ref.watch(siteEquipmentsProvider.future);
  final histories = await ref.watch(siteInspectionsProvider.future);
  
  // Current Status Counts
  int critical = 0;
  int warning = 0;
  int currentPass = 0;
  int unknown = 0;
  
  final anomalies = <SiteAnalysisDetail>[];
  final modelLifespans = <String, List<int>>{}; 
  final forecast = {3: 0, 6: 0, 12: 0};
  
  // Model Stats
  final modelDistribution = <String, int>{};
  final modelSensitivities = <String, List<double>>{};

  // 1. Analyze Current Status (Equipments)
  for (final item in equipments) {
    // Model Distribution
    final model = item.equipment.modelName ?? 'Unknown';
    modelDistribution[model] = (modelDistribution[model] ?? 0) + 1;

    // Status Counting
    bool counted = false;
    if (item.result == '不合格') {
      critical++;
      counted = true;
    } else if (item.result == '合格') {
      currentPass++;
      counted = true;
    }
    
    if (!counted) {
      if (item.dangerLevel == 0) critical++;
      else if (item.dangerLevel == 1) warning++;
      else if (item.dangerLevel == 2) currentPass++;
      else unknown++;
    }

    // Forecast
    if (item.daysRemaining != null && item.daysRemaining! > 0) {
      if (item.daysRemaining! < 90) forecast[3] = (forecast[3] ?? 0) + 1;
      if (item.daysRemaining! < 180) forecast[6] = (forecast[6] ?? 0) + 1;
      
      if (item.equipment.modelName != null && item.daysRemaining! < 3650) {
        modelLifespans.putIfAbsent(item.equipment.modelName!, () => []).add(item.daysRemaining!);
      }
    }
    
    // Anomaly Detail & Sensitivity Collection
    if (item.latestInspection != null) {
      final sens = item.latestInspection!.gasSensitivity;
      if (sens != null) {
        if (model != 'Unknown') {
          modelSensitivities.putIfAbsent(model, () => []).add(sens);
        }
        
        // Critical Anomaly Check (Sensitivity < 60% or Fail)
        if (sens < 60.0 || item.result == '不合格' || item.dangerLevel == 0) {
           anomalies.add(SiteAnalysisDetail(
             tagNo: item.equipment.tagNo,
             modelName: model,
             sensitivity: sens,
             date: item.latestInspection!.inspectionDate,
             reason: item.result == '不合格' ? '不合格判定' : '低感度 (<60%)',
           ));
        }
      }
    } else {
        // No inspection but critical (maybe predicted failure?)
        if (item.dangerLevel == 0) {
           anomalies.add(SiteAnalysisDetail(
             tagNo: item.equipment.tagNo,
             modelName: model,
             sensitivity: 0.0,
             date: DateTime.now(),
             reason: '高危険度 (予測またはデータなし)',
           ));
        }
    }
  }

  // 2. Analyze Historical Records (Inspections - siteInspectionsProvider)
  int totalRecords = 0;
  int totalPassRec = 0;
  int totalFailRec = 0;

  for (final h in histories) {
    totalRecords += h.inspections.length;
    for (final insp in h.inspections) {
      if (insp.result == '合格') totalPassRec++;
      else if (insp.result == '不合格') totalFailRec++;
    }
  }
  
  // Calculate Model Averages (Lifespan)
  final modelAverageLife = <String, double>{};
  modelLifespans.forEach((model, days) {
    if (days.isNotEmpty) {
      modelAverageLife[model] = days.reduce((a, b) => a + b) / days.length;
    }
  });

  // Calculate Model Average Sensitivity
  final modelAvgSens = <String, double>{};
  modelSensitivities.forEach((model, values) {
    if (values.isNotEmpty) {
      modelAvgSens[model] = values.reduce((a, b) => a + b) / values.length;
    }
  });
  
  double passRate = 0.0;
  if (totalRecords > 0) {
     passRate = (totalPassRec / totalRecords) * 100;
  } else if (equipments.isNotEmpty) {
     // Fallback if no history loaded but equipments exist? (Shouldn't happen if histories matches equipments)
     passRate = (currentPass / equipments.length) * 100;
  }

  return SiteAnalysis(
    totalSensors: equipments.length,
    totalRecords: totalRecords,
    criticalCount: critical,
    warningCount: warning,
    passCount: currentPass,
    unknownCount: unknown,
    totalPassRecords: totalPassRec,
    totalFailRecords: totalFailRec,
    anomalies: anomalies,
    modelAverageLife: modelAverageLife,
    replacementForecast: forecast,
    modelDistribution: modelDistribution,
    modelAverageSensitivity: modelAvgSens,
    overallPassRate: passRate,
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
