import 'dart:js_interop';

extension type _DemonTiltStatus._(JSObject _) implements JSObject {
  external bool get supported;
  external bool get active;
  external bool get calibrated;
  external double get roll;
  external double get neutral;
  external double get value;
}

@JS('demonTilt')
external JSObject? get _demonTiltObject;

@JS('demonTilt.enable')
external JSPromise<JSBoolean> _tiltEnable();

@JS('demonTilt.recalibrate')
external void _tiltRecalibrate();

@JS('demonTilt.disable')
external void _tiltDisable();

@JS('demonTilt.status')
external _DemonTiltStatus _tiltStatus();

class TiltController {
  TiltController();

  _DemonTiltStatus? get _status =>
      _demonTiltObject == null ? null : _tiltStatus();

  bool get isSupported => _status?.supported ?? false;
  bool get isActive => _status?.active ?? false;
  bool get isCalibrated => _status?.calibrated ?? false;
  double get steeringValue => (_status?.value ?? 0.0).clamp(-1.0, 1.0);
  double get rollDegrees => _status?.roll ?? 0.0;
  double get neutralDegrees => _status?.neutral ?? 0.0;

  Future<bool> enable() async {
    if (_demonTiltObject == null) return false;
    try {
      final result = await _tiltEnable().toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  void recalibrate() {
    if (_demonTiltObject == null) return;
    _tiltRecalibrate();
  }

  void disable() {
    if (_demonTiltObject == null) return;
    _tiltDisable();
  }
}
