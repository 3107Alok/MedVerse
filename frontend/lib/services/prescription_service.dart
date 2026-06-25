import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:frontend/config/api_config.dart';
import 'package:frontend/models/prescription_model.dart';

class PrescriptionService {
  Future<PrescriptionAnalysisResult> analyzePrescription(File imageFile) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/prescription/analyze');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Check file size (10MB limit)
    final int fileSize = await imageFile.length();
    if (fileSize > 10 * 1024 * 1024) {
      throw Exception('File size exceeds the 10MB limit.');
    }
    
    // Attach image file
    final stream = http.ByteStream(imageFile.openRead());
    final multipartFile = http.MultipartFile(
      'image',
      stream,
      fileSize,
      filename: imageFile.path.split('/').last,
    );
    request.files.add(multipartFile);
    
    try {
      // Send request with a timeout of 45 seconds to allow Gemini processing time
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PrescriptionAnalysisResult.fromJson(data);
        } else {
          throw Exception(data['message'] ?? 'Failed to parse prescription. The image might be unreadable.');
        }
      } else {
        Map<String, dynamic> errorData = {};
        try {
          errorData = jsonDecode(response.body);
        } catch (_) {}
        final errorMessage = errorData['error'] ?? 'Server error (${response.statusCode})';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on http.ClientException {
      throw Exception('Could not connect to the server. Please check your backend connection.');
    } catch (e) {
      rethrow;
    }
  }
}
