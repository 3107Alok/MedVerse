class HealthService {
  final Map<String, String> _specialistMapping = {
    'fever': 'General Physician',
    'headache': 'General Physician',
    'eye': 'Ophthalmologist',
    'heart': 'Cardiologist',
    'skin': 'Dermatologist',
    'bone': 'Orthopedic',
    'tooth': 'Dentist',
    'child': 'Pediatrician',
    'women': 'Gynecologist',
    'mental': 'Psychiatrist',
  };

  Future<Map<String, dynamic>> getChatResponse(String query) async {
    // Simulate thinking delay
    await Future.delayed(Duration(seconds: 1));

    String lowerQuery = query.toLowerCase();
    String specialist = 'General Physician'; // Default

    _specialistMapping.forEach((key, value) {
      if (lowerQuery.contains(key)) {
        specialist = value;
      }
    });

    return {
      'response': "Based on your symptoms, you should consult a $specialist.",
      'specialist': specialist
    };
  }

  Future<Map<String, dynamic>> processPrescription(String imagePath) async {
    // This feature is temporarily disabled as it requires a backend OCR engine.
    throw Exception('Prescription processing (OCR) is currently disabled.');
  }
}
