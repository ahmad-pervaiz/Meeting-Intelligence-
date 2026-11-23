import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/meeting.dart';

class ApiService {
  // Default to 10.0.2.2 for Android Emulator, or 127.0.0.1 for desktop/web testing
  static String baseUrl = "http://10.0.2.2:8000";

  static void updateBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Meeting>> getMeetings() async {
    final res = await http.get(Uri.parse('$baseUrl/api/meetings'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((e) => Meeting.fromJson(e)).toList();
    }
    throw Exception('Failed to load meetings: ${res.statusCode}');
  }

  static Future<Meeting> getMeeting(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/meetings/$id'));
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return Meeting.fromJson(data);
    }
    throw Exception('Failed to load meeting details: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> uploadMeeting({
    required String title,
    required List<Participant> participants,
    required String audioPath,
  }) async {
    final uri = Uri.parse('$baseUrl/api/meetings/upload');
    final request = http.MultipartRequest('POST', uri);

    request.fields['title'] = title;
    request.fields['participants'] = jsonEncode(
      participants.map((p) => p.toJson()).toList(),
    );

    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Audio upload failed: ${response.statusCode} - ${response.body}');
  }

  static Future<Meeting> mapSpeakers(String meetingId, Map<String, String> mapping) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/meetings/$meetingId/speakers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mapping': mapping}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return Meeting.fromJson(data);
    }
    throw Exception('Speaker mapping failed: ${res.statusCode}');
  }

  static Future<AskResponse> askQuestion(String meetingId, String question) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/meetings/$meetingId/ask'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return AskResponse.fromJson(data);
    }
    throw Exception('RAG Query failed: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> distributeMoM(String meetingId, {String? customMessage}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/meetings/$meetingId/distribute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'custom_message': customMessage}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Email distribution failed: ${res.statusCode} - ${res.body}');
  }

  static Future<File> downloadPdf(String meetingId, String savePath) async {
    final res = await http.get(Uri.parse('$baseUrl/api/meetings/$meetingId/pdf'));
    if (res.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(res.bodyBytes);
      return file;
    }
    throw Exception('PDF download failed: ${res.statusCode}');
  }
}
