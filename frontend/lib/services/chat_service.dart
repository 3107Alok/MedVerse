import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:frontend/config/api_config.dart';
import 'package:frontend/models/chat_message.dart';

class ChatService {
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat');
    
    // Slice history to the last 10 messages to limit size and respect context requirements
    final contextHistory = history.length > 10 
        ? history.sublist(history.length - 10) 
        : history;
        
    final body = jsonEncode({
      'message': message,
      'history': contextHistory.map((msg) => msg.toJson()).toList(),
    });
    
    print('DEBUG: ChatService.sendMessage called');
    print('DEBUG: Request URL: $uri');
    print('DEBUG: Request Method: POST');
    print('DEBUG: Request Body: $body');
    
    try {
      print('DEBUG: Sending HTTP request to Flask backend...');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));
      
      print('DEBUG: HTTP response received. Status: ${response.statusCode}');
      print('DEBUG: Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['response'] ?? '';
        } else {
          throw Exception(data['error'] ?? 'Unknown error response from AI.');
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
    } on TimeoutException {
      throw Exception('Connection timeout. The AI healthcare assistant is taking too long to respond.');
    } on http.ClientException {
      throw Exception('Could not reach the server. Please check if the backend is running.');
    } catch (e) {
      rethrow;
    }
  }
}
