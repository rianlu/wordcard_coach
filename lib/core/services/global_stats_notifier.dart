import 'package:flutter/foundation.dart';

/// A simple singleton notifier to broadcast when global statistics 
/// (like word progress, daily activity) have changed.
class GlobalStatsNotifier extends ChangeNotifier {
  static final GlobalStatsNotifier _instance = GlobalStatsNotifier._internal();
  
  factory GlobalStatsNotifier() => _instance;
  
  static GlobalStatsNotifier get instance => _instance;

  GlobalStatsNotifier._internal();

  void notify() {
    notifyListeners();
  }
}
