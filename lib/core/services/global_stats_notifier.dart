import 'package:flutter/foundation.dart';

/// 逻辑处理
/// 逻辑处理
class GlobalStatsNotifier extends ChangeNotifier {
  static final GlobalStatsNotifier _instance = GlobalStatsNotifier._internal();
  
  factory GlobalStatsNotifier() => _instance;
  
  static GlobalStatsNotifier get instance => _instance;

  GlobalStatsNotifier._internal();

  void notify() {
    notifyListeners();
  }
}
