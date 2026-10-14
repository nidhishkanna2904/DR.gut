import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config.dart';
import '../models/calorie_estimate.dart';
import '../models/diet_plan.dart';
import '../models/user_profile.dart';

/// A single message in the diet bot conversation.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  /// Sends the user profile, GPS location, and the blood report bytes to the backend.
  /// Works across Android, iOS, Desktop, and Web.
  static Future<DietPlan> createPlan(
    UserProfile profile,
    Uint8List reportBytes,
    String reportName,
  ) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/diet-plan');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = profile.name;
    request.fields['phone'] = profile.phone;
    request.fields['location'] = profile.locationName;
    request.fields['lat'] = profile.lat.toString();
    request.fields['lng'] = profile.lng.toString();
    request.fields['disease'] = profile.disease;
    request.fields['allergies'] = profile.allergies;
    request.fields['dislikes'] = profile.dislikes;
    request.fields['budget'] = profile.budget.toString();
    request.fields['plan_type'] = profile.planType;

    // Detect MIME type
    final ext = reportName.split('.').last.toLowerCase();
    MediaType mediaType;
    if (ext == 'pdf') {
      mediaType = MediaType('application', 'pdf');
    } else if (ext == 'png') {
      mediaType = MediaType('image', 'png');
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'report',
      reportBytes,
      filename: reportName,
      contentType: mediaType,
    );
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return DietPlan.fromJson(decoded);
      } else {
        String detailMessage = 'Server error (${response.statusCode})';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody.containsKey('detail')) {
            detailMessage = errorBody['detail'].toString();
          }
        } catch (_) {}

        if (response.statusCode == 400) {
          throw ApiException(detailMessage, 400);
        } else if (response.statusCode == 502) {
          throw const ApiException('AI service is temporarily unavailable. Please try again in a few moments.', 502);
        } else {
          throw ApiException(detailMessage, response.statusCode);
        }
      }
    } on TimeoutException {
      throw const ApiException('The analysis request timed out. Please check your connection and try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('failed to fetch') || msg.contains('xmlhttprequest')) {
        throw const ApiException('Cannot reach Dr Gut server. Make sure the backend is running at http://localhost:8000.');
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Sends a food photo to the backend for AI-powered calorie estimation.
  static Future<CalorieEstimate> estimateCalories(
    Uint8List photoBytes,
    String photoName,
  ) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/estimate-calories');
    final request = http.MultipartRequest('POST', uri);

    final ext = photoName.split('.').last.toLowerCase();
    MediaType mediaType;
    if (ext == 'png') {
      mediaType = MediaType('image', 'png');
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    request.files.add(http.MultipartFile.fromBytes(
      'photo',
      photoBytes,
      filename: photoName,
      contentType: mediaType,
    ));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return CalorieEstimate.fromJson(decoded);
      } else {
        String detailMessage = 'Calorie analysis failed (${response.statusCode})';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody.containsKey('detail')) {
            detailMessage = errorBody['detail'].toString();
          }
        } catch (_) {}
        // 503 = credit exhausted, 502 = API temporarily down — surface the real message
        throw ApiException(detailMessage, response.statusCode);
      }
    } on TimeoutException {
      throw const ApiException('Calorie estimation timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('failed to fetch') || msg.contains('xmlhttprequest')) {
        throw const ApiException('Cannot reach Dr Gut server. Make sure the backend is running.');
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Sends a chat message to the diet AI assistant with the current plan context.
  static Future<String> sendDietChatMessage({
    required String message,
    required DietPlan plan,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/diet-chat');

    // Build a compact days preview for the first 3 days
    final daysPreview = plan.days.take(3).map((day) {
      return {
        'day': day.day,
        'meals': day.meals
            .map((m) => {'time': m.time, 'items': m.items})
            .toList(),
      };
    }).toList();

    final body = jsonEncode({
      'message': message,
      'plan_summary': plan.summary,
      'plan_deficiencies': plan.deficiencies.map((d) => d.toJson()).toList(),
      'plan_days_preview': daysPreview,
      'local_notes': plan.localNotes,
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['reply'] as String? ?? 'Sorry, I could not generate a response.';
      } else {
        // Surface the actual error message from the server (e.g. credit exhausted, API down)
        String detail = 'AI assistant error (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err.containsKey('detail')) {
            detail = err['detail'].toString();
          }
        } catch (_) {}
        // Return as a bot message rather than throwing, so the user sees it in-chat
        return '⚠️ $detail';
      }
    } on TimeoutException {
      return '⚠️ The assistant took too long to respond. Please try again.';
    } catch (e) {
      if (e is ApiException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('failed to fetch') || msg.contains('xmlhttprequest')) {
        return '⚠️ Cannot reach Dr. Gut server. Please check that the backend is running.';
      }
      return '⚠️ Chat error: $e';
    }
  }
}

