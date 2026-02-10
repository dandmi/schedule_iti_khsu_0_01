import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/schedule_response.dart';

// ==========================
// МОДЕЛИ ОТВЕТОВ
// ==========================



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

class GroupsResponse {
  final List<String> groups;

  GroupsResponse({required this.groups});

  factory GroupsResponse.fromJson(Map<String, dynamic> json) {
    return GroupsResponse(
      groups: List<String>.from(json['groups'] ?? []),
    );
  }
}

// ==========================
// API КЛИЕНТ
// ==========================

class ApiClient {
  static const String baseUrl = 'https://t2iti.khsu.ru/api';

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // Получить расписание группы
  Future<ScheduleResponse> getGroupSchedule(String group, DateTime date) async {
    final uri = Uri.parse('$baseUrl/getpairs/date:$group:${_formatDate(date)}');
    final json = await _getJson(uri);
    return ScheduleResponse.fromJson(json);
  }

  // Получить расписание преподавателя
  Future<ScheduleResponse> getTeacherSchedule(String name, DateTime date) async {
    final uri = Uri.parse('$baseUrl/getpairs/teacher:$name:${_formatDate(date)}');
    final json = await _getJson(uri);
    return ScheduleResponse.fromJson(json);
  }

  // Получить расписание аудитории
  Future<ScheduleResponse> getAuditorySchedule(String auditory, DateTime date) async {
    final uri = Uri.parse('$baseUrl/getpairs/auditory:$auditory:${_formatDate(date)}');
    final json = await _getJson(uri);
    return ScheduleResponse.fromJson(json);
  }

  // Получить список групп по курсу
  Future<GroupsResponse> getGroups(int course) async {
    final uri = Uri.parse('$baseUrl/getgroups/$course');
    final json = await _getJson(uri);
    return GroupsResponse.fromJson(json);
  }

  // Поиск
  Future<SearchResponse> search(String query) async {
    final uri = Uri.parse('$baseUrl/search/$query');
    final json = await _getJson(uri);
    return SearchResponse.fromJson(json);
  }
}