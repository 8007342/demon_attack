(function () {
  'use strict';

  const RADIANS = Math.PI / 180;
  const FULL_LOCK_DEG = 26;
  const DEADZONE = 0.025;
  const TAU_SECONDS = 0.09;
  const CALIBRATION_MIN_SAMPLES = 3;
  const CALIBRATION_MIN_MS = 200;

  let active = false;
  let calibrated = false;
  let roll = 0;
  let neutral = 0;
  let value = 0;
  let lastTimestampMs = 0;

  let calSamples = 0;
  let calStartMs = 0;
  let calSinSum = 0;
  let calCosSum = 0;

  function screenAngle() {
    if (window.screen && window.screen.orientation && typeof window.screen.orientation.angle === 'number') {
      return window.screen.orientation.angle;
    }
    if (typeof window.orientation === 'number') {
      return window.orientation;
    }
    return 0;
  }

  /**
   * 3D gravity projection using the third row of the W3C DeviceOrientationEvent
   * rotation matrix rotated by screen.orientation.angle.
   */
  function screenRoll(beta, gamma, angle) {
    if (typeof beta !== 'number' || typeof gamma !== 'number' || !Number.isFinite(beta) || !Number.isFinite(gamma)) {
      return null;
    }
    const b = beta * RADIANS;
    const g = gamma * RADIANS;
    const a = (typeof angle === 'number' && Number.isFinite(angle) ? angle : 0) * RADIANS;

    // Third row of W3C rotation matrix (gravity vector in device frame)
    const gx = -Math.cos(b) * Math.sin(g);
    const gy = Math.sin(b);

    const screenX = gx * Math.cos(a) - gy * Math.sin(a);
    const screenY = gx * Math.sin(a) + gy * Math.cos(a);

    if (Math.hypot(screenX, screenY) < 0.15) {
      return null;
    }
    return -Math.atan2(screenX, screenY) / RADIANS;
  }

  function shortestAngleDelta(deg, refDeg) {
    return ((deg - refDeg + 540) % 360) - 180;
  }

  function resetCalibrationState() {
    calibrated = false;
    calSamples = 0;
    calStartMs = 0;
    calSinSum = 0;
    calCosSum = 0;
  }

  function onDeviceOrientation(event) {
    if (!active) return;
    const currentRoll = screenRoll(event.beta, event.gamma, screenAngle());
    if (currentRoll === null) return;

    const now = performance.now();
    roll = currentRoll;

    if (!calibrated) {
      if (calSamples === 0) {
        calStartMs = now;
      }
      calSamples += 1;
      calSinSum += Math.sin(currentRoll * RADIANS);
      calCosSum += Math.cos(currentRoll * RADIANS);
      if (calSamples >= CALIBRATION_MIN_SAMPLES && (now - calStartMs) >= CALIBRATION_MIN_MS) {
        neutral = Math.atan2(calSinSum, calCosSum) / RADIANS;
        calibrated = true;
        lastTimestampMs = now;
      }
      return;
    }

    const deltaDeg = shortestAngleDelta(currentRoll, neutral);
    const rawTarget = Math.max(-1, Math.min(1, deltaDeg / FULL_LOCK_DEG));
    const target = Math.abs(rawTarget) < DEADZONE ? 0 : rawTarget;

    const dt = lastTimestampMs > 0 ? Math.max(0.001, Math.min(0.25, (now - lastTimestampMs) / 1000)) : 0.016;
    lastTimestampMs = now;

    const alpha = 1 - Math.exp(-dt / TAU_SECONDS);
    value = value + (target - value) * alpha;
    if (Math.abs(value) < 0.001 && target === 0) {
      value = 0;
    }
  }

  function isSupported() {
    return typeof window !== 'undefined' && 'DeviceOrientationEvent' in window;
  }

  async function enable() {
    if (!isSupported()) {
      return false;
    }
    try {
      if (typeof DeviceOrientationEvent !== 'undefined' &&
          typeof DeviceOrientationEvent.requestPermission === 'function') {
        const permission = await DeviceOrientationEvent.requestPermission();
        if (permission !== 'granted') {
          return false;
        }
      }
    } catch (_) {
      return false;
    }

    if (!active) {
      resetCalibrationState();
      value = 0;
      lastTimestampMs = 0;
      window.addEventListener('deviceorientation', onDeviceOrientation, false);
      active = true;
    }
    return true;
  }

  function recalibrate() {
    resetCalibrationState();
    value = 0;
    lastTimestampMs = 0;
  }

  function disable() {
    if (active) {
      window.removeEventListener('deviceorientation', onDeviceOrientation, false);
      active = false;
    }
    resetCalibrationState();
    value = 0;
    lastTimestampMs = 0;
  }

  function status() {
    return {
      supported: isSupported(),
      active: active,
      calibrated: calibrated,
      roll: roll,
      neutral: neutral,
      value: value,
    };
  }

  window.demonTilt = {
    screenRoll: screenRoll,
    enable: enable,
    recalibrate: recalibrate,
    disable: disable,
    status: status,
  };
})();
