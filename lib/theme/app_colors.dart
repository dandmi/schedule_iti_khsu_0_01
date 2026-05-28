import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

// Светлая тема
  static const Color lightPrimary = Color(0xFF2F6B45);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);

  static const Color lightPrimaryContainer = Color(0xFFCFE4CE);
  static const Color lightOnPrimaryContainer = Color(0xFF173823);

  static const Color lightSecondary = Color(0xFF52634F);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);

  static const Color lightSecondaryContainer = Color(0xFFDDE9D7);
  static const Color lightOnSecondaryContainer = Color(0xFF202A1F);

  static const Color lightBackground = Color(0xFFF1F5EC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHighest = Color(0xFFE1E9DC);

  static const Color lightOnSurface = Color(0xFF1C1F1B);
  static const Color lightOnSurfaceVariant = Color(0xFF4D574C);

  static const Color lightOutlineVariant = Color(0xFFC2CDBD);
  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);

  static const Color lightSchedulePickerBackground = Color(0xFFFFFFFF);

// Тёмная тема
  static const Color darkPrimary = Color(0xFF9FD8AF);
  static const Color darkOnPrimary = Color(0xFF0E2517);

  static const Color darkPrimaryContainer = Color(0xFF183427);
  static const Color darkOnPrimaryContainer = Color(0xFFD7F0DD);

  static const Color darkBackground = Color(0xFF0F1411);
  static const Color darkSurface = Color(0xFF151B17);
  static const Color darkSurfaceContainerHighest = Color(0xFF1E2620);

  static const Color darkOnSurface = Color(0xFFE7EEE7);
  static const Color darkOnSurfaceVariant = Color(0xFFB2BDB3);

  static const Color darkOutlineVariant = Color(0xFF364238);

  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);

  static const Color darkSchedulePickerBackground = Color(0xFF213328);

  // Индикаторы сроков заметок
  static const Color deadlineOk = lightPrimary;
  static const Color deadlineSoon = Color(0xFF9A6A00);
  static const Color deadlineOverdue = lightError;

  static Color schedulePickerBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSchedulePickerBackground
        : lightSchedulePickerBackground;
  }

  static const LessonBlockStyle lightLecture = LessonBlockStyle(
    background: Color(0xFFDCEFE0),
    border: Color(0xFF9EC3AA),
    accent: Color(0xFF2F6B45),
  );

  static const LessonBlockStyle lightPractice = LessonBlockStyle(
    background: Color(0xFFDCE9FA),
    border: Color(0xFFA9BFE0),
    accent: Color(0xFF2E5E9E),
  );

  static const LessonBlockStyle lightLaboratory = LessonBlockStyle(
    background: Color(0xFFFFF0BF),
    border: Color(0xFFD1B15A),
    accent: Color(0xFF8C6200),
  );

  static const LessonBlockStyle lightExam = LessonBlockStyle(
    background: Color(0xFFFFE0E6),
    border: Color(0xFFD7919E),
    accent: Color(0xFF9C2F45),
  );

  static const LessonBlockStyle lightUnknownLesson = LessonBlockStyle(
    background: Color(0xFFEFF1EC),
    border: Color(0xFFC4C9C0),
    accent: Color(0xFF1C1F1B),
  );

  static const LessonBlockStyle darkLecture = LessonBlockStyle(
    background: Color(0xFF203629),
    border: Color(0xFF4B7B5E),
    accent: Color(0xFFBDE8C7),
  );

  static const LessonBlockStyle darkPractice = LessonBlockStyle(
    background: Color(0xFF24344A),
    border: Color(0xFF4A6D98),
    accent: Color(0xFFB8D5FF),
  );

  static const LessonBlockStyle darkLaboratory = LessonBlockStyle(
    background: Color(0xFF3A2D16),
    border: Color(0xFF7B6335),
    accent: Color(0xFFFFD98A),
  );

  static const LessonBlockStyle darkExam = LessonBlockStyle(
    background: Color(0xFF4B2228),
    border: Color(0xFF8F4A56),
    accent: Color(0xFFFFB3C1),
  );

  static const LessonBlockStyle darkUnknownLesson = LessonBlockStyle(
    background: Color(0xFF2E2E31),
    border: Color(0xFF55585E),
    accent: Color(0xFFE6E7EA),
  );

  static LessonBlockStyle lessonStyle({
    required BuildContext context,
    required String typeLesson,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = typeLesson.toLowerCase().trim();

    if (t.contains('зач') || t.contains('экз')) {
      return isDark ? darkExam : lightExam;
    }

    if (t.contains('лаб')) {
      return isDark ? darkLaboratory : lightLaboratory;
    }

    if (t.contains('пр')) {
      return isDark ? darkPractice : lightPractice;
    }

    if (t.contains('л')) {
      return isDark ? darkLecture : lightLecture;
    }

    return isDark ? darkUnknownLesson : lightUnknownLesson;
  }
}

class LessonBlockStyle {
  final Color background;
  final Color border;
  final Color accent;

  const LessonBlockStyle({
    required this.background,
    required this.border,
    required this.accent,
  });
}