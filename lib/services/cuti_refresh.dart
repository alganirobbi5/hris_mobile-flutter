import 'package:flutter/foundation.dart';

class CutiRefresh {
  CutiRefresh._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notify() {
    revision.value++;
  }
}
