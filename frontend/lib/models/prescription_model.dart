class MedicineModel {
  final String name;
  final String strength;
  final String dosage;
  final String frequency;
  final String duration;
  final String instruction;

  MedicineModel({
    required this.name,
    required this.strength,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instruction,
  });

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    return MedicineModel(
      name: json['name'] ?? '',
      strength: json['strength'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
      instruction: json['instruction'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'strength': strength,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instruction': instruction,
    };
  }
}

class LabResultModel {
  final String parameter;
  final String value;
  final String unit;
  final String referenceRange;
  final String status;
  final String explanation;

  LabResultModel({
    required this.parameter,
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.status,
    required this.explanation,
  });

  factory LabResultModel.fromJson(Map<String, dynamic> json) {
    return LabResultModel(
      parameter: json['parameter'] ?? '',
      value: json['value'] ?? '',
      unit: json['unit'] ?? '',
      referenceRange: json['reference_range'] ?? '',
      status: json['status'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parameter': parameter,
      'value': value,
      'unit': unit,
      'reference_range': referenceRange,
      'status': status,
      'explanation': explanation,
    };
  }
}

class PrescriptionAnalysisResult {
  final bool success;
  final String message;
  final String patientName;
  final String doctorName;
  final String hospital;
  final String date;
  final String diagnosis;
  final List<MedicineModel> medicines;
  final String followUp;
  final String notes;

  // Optional extended analyzer fields
  final String documentType;
  final String reportType;
  final double confidence;
  final List<LabResultModel> labResults;
  final String summary;
  final String recommendation;
  final String warnings;

  PrescriptionAnalysisResult({
    required this.success,
    this.message = '',
    required this.patientName,
    required this.doctorName,
    required this.hospital,
    required this.date,
    required this.diagnosis,
    required this.medicines,
    required this.followUp,
    required this.notes,
    this.documentType = 'Prescription',
    this.reportType = '',
    this.confidence = 1.0,
    this.labResults = const [],
    this.summary = '',
    this.recommendation = '',
    this.warnings = '',
  });

  factory PrescriptionAnalysisResult.fromJson(Map<String, dynamic> json) {
    var medListRaw = json['medicines'] as List? ?? [];
    List<MedicineModel> medicinesList = medListRaw.map((i) => MedicineModel.fromJson(i)).toList();

    var labListRaw = json['lab_results'] as List? ?? [];
    List<LabResultModel> labResultsList = labListRaw.map((i) => LabResultModel.fromJson(i)).toList();

    return PrescriptionAnalysisResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      patientName: json['patient_name'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      hospital: json['hospital'] ?? '',
      date: json['date'] ?? '',
      diagnosis: json['diagnosis'] ?? '',
      medicines: medicinesList,
      followUp: json['follow_up'] ?? '',
      notes: json['notes'] ?? '',
      documentType: json['document_type'] ?? 'Prescription',
      reportType: json['report_type'] ?? '',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      labResults: labResultsList,
      summary: json['summary'] ?? '',
      recommendation: json['recommendation'] ?? '',
      warnings: json['warnings'] ?? '',
    );
  }
}
