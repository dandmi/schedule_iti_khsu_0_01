import 'package:flutter/foundation.dart';

class AppRefreshBus {
  static final ValueNotifier<int> notesVersion = ValueNotifier<int>(0);
  static final ValueNotifier<int> scheduleVersion = ValueNotifier<int>(0);

  static void markNotesChanged() {
    notesVersion.value++;
  }

  static void markScheduleChanged() {
    scheduleVersion.value++;
  }
}