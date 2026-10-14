import 'package:flutter/cupertino.dart';

import '../Models/cloud_control.dart';

final LoftifyControlProvider controlProvider = LoftifyControlProvider();

/// Retains the existing UI provider boundary without mutable remote state.
class LoftifyControlProvider with ChangeNotifier {
  final LoftifyControl globalControl = LoftifyControl.community;
}
