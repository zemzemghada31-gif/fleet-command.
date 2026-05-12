import 'package:flutter/foundation.dart';

class NavService extends ChangeNotifier {
  static final NavService instance = NavService._();
  NavService._();

  int _targetPage = 0;
  String _targetPlate = '';
  String _targetModel = '';
  bool _needsNavigation = false;

  int get targetPage => _targetPage;
  String get targetPlate => _targetPlate;
  String get targetModel => _targetModel;
  bool get needsNavigation => _needsNavigation;

  void navigate(int page, String plate, String model) {
    _targetPage = page;
    _targetPlate = plate;
    _targetModel = model;
    _needsNavigation = true;
    notifyListeners();
  }

  void consume() {
    _needsNavigation = false;
    notifyListeners();
  }
}
