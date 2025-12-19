class SiteModel {
  final String id;
  final String code;
  final String name;

  SiteModel({required this.id, required this.code, required this.name});

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    return SiteModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
    };
  }
}

class EquipmentModel {
  final String id;
  final String siteId;
  final String tagNo;
  final String? serialNo;
  final String? modelName;
  final String? sensorType;
  final String? gasName;
  final double? fullScale;

  EquipmentModel({
    required this.id,
    required this.siteId,
    required this.tagNo,
    this.serialNo,
    this.modelName,
    this.sensorType,
    this.gasName,
    this.fullScale,
  });

  factory EquipmentModel.fromJson(Map<String, dynamic> json) {
    return EquipmentModel(
      id: json['id'],
      siteId: json['site_id'],
      tagNo: json['tag_no'],
      serialNo: json['serial_no'],
      modelName: json['model_name'],
      sensorType: json['sensor_type'],
      gasName: json['gas_name'],
      fullScale: json['full_scale'] != null ? (json['full_scale'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'tag_no': tagNo,
      'serial_no': serialNo,
      'model_name': modelName,
      'sensor_type': sensorType,
      'gas_name': gasName,
      'full_scale': fullScale,
    };
  }
}

class InspectionModel {
  final String id;
  final String equipmentId;
  final DateTime inspectionDate;
  final double? gasSensitivity;
  final double? adjustmentBefore;
  final double? adjustmentAfter;
  final bool isSensorReplaced;
  final String? result;

  InspectionModel({
    required this.id,
    required this.equipmentId,
    required this.inspectionDate,
    this.gasSensitivity,
    this.adjustmentBefore,
    this.adjustmentAfter,
    required this.isSensorReplaced,
    this.result,
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) {
    return InspectionModel(
      id: json['id'],
      equipmentId: json['equipment_id'],
      inspectionDate: DateTime.parse(json['inspection_date']),
      gasSensitivity: json['gas_sensitivity'] != null ? (json['gas_sensitivity'] as num).toDouble() : null,
      adjustmentBefore: json['adjustment_before'] != null ? (json['adjustment_before'] as num).toDouble() : null,
      adjustmentAfter: json['adjustment_after'] != null ? (json['adjustment_after'] as num).toDouble() : null,
      isSensorReplaced: json['is_sensor_replaced'] ?? false,
      result: json['result'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'equipment_id': equipmentId,
      'inspection_date': inspectionDate.toIso8601String(),
      'gas_sensitivity': gasSensitivity,
      'adjustment_before': adjustmentBefore,
      'adjustment_after': adjustmentAfter,
      'is_sensor_replaced': isSensorReplaced,
      'result': result,
    };
  }
}
