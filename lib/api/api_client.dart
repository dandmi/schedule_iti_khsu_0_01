import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/schedule_response.dart';
import '../utils/schedule_type.dart';

class SearchResponse {
  final List<String> names;
  final List<String> courses;
  final List<String> teacherNames;
  final List<String> auditories;

  SearchResponse({
    required this.names,
    required this.courses,
    required this.teacherNames,
    required this.auditories,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      names: List<String>.from(json['names'] ?? []),
      courses: List<String>.from(json['courses'] ?? []),
      teacherNames: List<String>.from(json['tnames'] ?? []),
      auditories: List<String>.from(json['auditories'] ?? []),
    );
  }
}

class ApiClient {
  static const String baseUrl = 'https://t2.iti-khsu.ru/api';

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<bool> hasInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://t2.iti-khsu.ru'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode > 0;
    } catch (_) {
      return false;
    }
  }

  Future<ScheduleResponse> fetchSchedule({
    required ScheduleType type,
    required String value,
    required DateTime date,
  }) async {
    switch (type) {
      case ScheduleType.group:
        return getGroupSchedule(value, date);
      case ScheduleType.teacher:
        return getTeacherSchedule(value, date);
      case ScheduleType.auditory:
        return getAuditorySchedule(value, date);
    }
  }

  Future<ScheduleResponse> getGroupSchedule(String group, DateTime date) async {
    final uri = Uri.parse('$baseUrl/getpairs/date:$group:${_formatDate(date)}');
    final json = await _getJson(uri);
    return ScheduleResponse.fromJson(json);
  }

  Future<ScheduleResponse> getTeacherSchedule(String name, DateTime date) async {
    final uri =
    Uri.parse('$baseUrl/getpairs/teacher:$name:${_formatDate(date)}');
    final json = await _getJson(uri);
    return ScheduleResponse.fromJson(json);
  }

  Future<ScheduleResponse> getAuditorySchedule(
      String auditory,
      DateTime date,
      ) async {
    final uri =
    Uri.parse('$baseUrl/getpairs/auditory:$auditory:${_formatDate(date)}');
    final json = await _getJson(uri);
    return ScheduleResponse.fromJson(json);
  }

  Future<SearchResponse> search(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('$baseUrl/search/$encoded');
    final json = await _getJson(uri);
    return SearchResponse.fromJson(json);
  }
}