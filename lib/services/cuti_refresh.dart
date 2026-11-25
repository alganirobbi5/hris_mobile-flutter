import 'package:flutter/foundation.dart';

class LeaveUpdate {
  const LeaveUpdate({required this.status, required this.title});

  final int status;
  final String title;
}

class CutiRefresh {
  CutiRefresh._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final ValueNotifier<LeaveUpdate?> lastUpdate =
      ValueNotifier<LeaveUpdate?>(null);

  static void notify({LeaveUpdate? update}) {
    if (update != null) lastUpdate.value = update;
    revision.value++;
  }
}
