class TiltController {
  TiltController();

  bool _active = false;
  bool _calibrated = false;
  double _steeringValue = 0;

  bool get isSupported => false;
  bool get isActive => _active;
  bool get isCalibrated => _calibrated;
  double get steeringValue => _steeringValue;
  double get rollDegrees => 0;
  double get neutralDegrees => 0;

  Future<bool> enable() async {
    _active = false;
    _calibrated = false;
    _steeringValue = 0;
    return false;
  }

  void recalibrate() {
    _calibrated = false;
    _steeringValue = 0;
  }

  void disable() {
    _active = false;
    _calibrated = false;
    _steeringValue = 0;
  }
}
