import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  final String _baseUrl = 'http://192.168.1.7:5000';

  String buildAbsoluteUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return '';
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    if (pathOrUrl.startsWith('/')) {
      return '$_baseUrl$pathOrUrl';
    }
    return '$_baseUrl/$pathOrUrl';
  }

  Future<void> createUserProfile({
    required String firebaseUid,
    required String email,
    required String name,
    required String role,
    required String rollNo,
    required String profileImage,
  }) async {
    try {
      final Uri url = Uri.parse('$_baseUrl/users/create');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': firebaseUid,
          'email': email,
          'name': name,
          'role': role,
          'roll_no': rollNo.isEmpty ? null : rollNo,
          'profile_image': profileImage.isEmpty ? null : profileImage,
        }),
      );

      // Debug logs for university project testing.
      print('Create user profile status: ${response.statusCode}');
      print('Create user profile body: ${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Backend error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('API request failed: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      final Uri url = Uri.parse('$_baseUrl/users/$firebaseUid');
      final response = await http.get(url);
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Backend error ${response.statusCode}: ${response.body}');
      }
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['user'] as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  Future<Map<String, dynamic>> createClassroom({
    required String classroomName,
    required String createdBy,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/classrooms/create');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'classroom_name': classroomName,
        'created_by': createdBy,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create classroom: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> joinClassroom({
    required String firebaseUid,
    required String classroomCode,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/classrooms/join');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firebase_uid': firebaseUid,
        'classroom_code': classroomCode,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to join classroom: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherClassrooms(String firebaseUid) async {
    final Uri url = Uri.parse('$_baseUrl/classrooms/teacher/$firebaseUid');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load classrooms: ${response.body}');
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    return (data['classrooms'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getStudentClassrooms(String firebaseUid) async {
    final Uri url = Uri.parse('$_baseUrl/classrooms/student/$firebaseUid');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load classrooms: ${response.body}');
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    return (data['classrooms'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>?> getActiveExamSession(String classroomId) async {
    final Uri url = Uri.parse('$_baseUrl/exam/active/$classroomId');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to check active exam session: ${response.body}');
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data['session'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> startExamSession({
    required String classroomId,
    required String examName,
    required String startedBy,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/exam/start');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'classroom_id': classroomId,
        'exam_name': examName,
        'started_by': startedBy,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to start exam session: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> endExamSession({
    required String sessionId,
    required String endedBy,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/exam/end');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'ended_by': endedBy,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to end exam session: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkMonitoringFrame({
    required File frameFile,
    required String classroomId,
    required String sessionId,
  }) async {
    final Uri url = Uri.parse('$_baseUrl/monitoring/check-frame');
    final request = http.MultipartRequest('POST', url)
      ..fields['classroom_id'] = classroomId
      ..fields['session_id'] = sessionId
      ..files.add(await http.MultipartFile.fromPath('frame', frameFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to check frame: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMonitoringAlerts(String sessionId) async {
    final Uri url = Uri.parse('$_baseUrl/monitoring/alerts/$sessionId');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load alerts: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['alerts'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getExamHistory(String classroomId) async {
    final Uri url = Uri.parse('$_baseUrl/exam-history/$classroomId');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load exam history: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['history'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getExamNotifications(String sessionId) async {
    final Uri url = Uri.parse('$_baseUrl/exam-notifications/$sessionId');
    final response = await http.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load exam notifications: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['notifications'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
