import 'dart:typed_data';

// ══════════════════════════════════════════════════════════════════════════════
// Arduino Command Protocol
// ══════════════════════════════════════════════════════════════════════════════
// This file contains all Arduino-specific protocol definitions and command
// encoding logic for communicating with the RC car Arduino controller.
// ══════════════════════════════════════════════════════════════════════════════

// ── Command Buffer Constants ──────────────────────────────────────────────────
const int kCmdBufLen = 16;
const int kStartByte = 0xFF; // framing sentinel

// Command buffer indices (must match Arduino firmware)
const int kIdxHeadLight = 0;
const int kIdxFogLight = 1;
const int kIdxIndRight = 2;
const int kIdxIndLeft = 3;
const int kIdxReverseLight = 4;
const int kIdxBrakeLight = 5;
const int kIdxSteering = 7; // 0-180 (50 = centre)
const int kIdxMotorEn = 8; // 0-255 throttle
const int kIdxMotorIn1 = 9; // direction bit
const int kIdxMotorIn2 = 10; // direction bit

// ── Telemetry Buffer Constants ────────────────────────────────────────────────
const int kTelemBufLen = 8;
const int kTIdxBattInt = 0;
const int kTIdxBattDec = 1;
const int kTIdxRpmLo = 2;
const int kTIdxRpmHi = 3;
const int kTIdxSpeedLo = 4;
const int kTIdxSpeedHi = 5;
const int kTIdxBattPct = 6;

// ══════════════════════════════════════════════════════════════════════════════
// Arduino Command Builder
// ══════════════════════════════════════════════════════════════════════════════

class ArduinoCommandBuilder {
  /// Builds a complete Arduino command buffer with framing
  /// Returns a framed Uint8List ready to send to the Arduino
  static Uint8List buildCommand({
    required int steering,
    required int throttle,
    required bool motorIn1,
    required bool motorIn2,
    required bool headLight,
    required bool highBeam,
    required bool fogLight,
    required bool indicatorLeft,
    required bool indicatorRight,
    required bool reverseLight,
    required bool brakeLight,
    required bool lowIntensityBrakeLight,
  }) {
    final buf = Uint8List(kCmdBufLen);

    // Set light and indicator states
    buf[kIdxHeadLight] = highBeam
        ? 255
        : headLight
        ? 120
        : 0;
    buf[kIdxFogLight] = fogLight ? 1 : 0;
    buf[kIdxIndRight] = indicatorRight ? 1 : 0;
    buf[kIdxIndLeft] = indicatorLeft ? 1 : 0;
    // buf[kIdxHorn] = horn ? 1 : 0;
    buf[kIdxSteering] = steering.clamp(0, 180);

    final int brakeLightValue = brakeLight
        ? 254
        : lowIntensityBrakeLight
        ? 100
        : 0;

    // Set motor control states
    if (brakeLight) {
      // L298N brake simulation: EN, IN1, IN2 all HIGH
      buf[kIdxMotorEn] = 255;
      buf[kIdxMotorIn1] = 255;
      buf[kIdxMotorIn2] = 255;
      buf[kIdxBrakeLight] = brakeLightValue;
      buf[kIdxReverseLight] = 0;
    } else if (motorIn1 && !motorIn2) {
      // Forward
      buf[kIdxMotorIn1] = 1;
      buf[kIdxMotorIn2] = 0;
      buf[kIdxBrakeLight] = brakeLightValue;
      buf[kIdxReverseLight] = 0;
      buf[kIdxMotorEn] = throttle.clamp(0, 255);
    } else if (!motorIn1 && motorIn2) {
      // Reverse
      buf[kIdxMotorIn1] = 0;
      buf[kIdxMotorIn2] = 1;
      buf[kIdxReverseLight] = 1;
      buf[kIdxBrakeLight] = brakeLightValue;
      buf[kIdxMotorEn] = throttle.clamp(0, 255);
    } else {
      // Neutral
      buf[kIdxMotorIn1] = 0;
      buf[kIdxMotorIn2] = 0;
      buf[kIdxBrakeLight] = brakeLightValue;
      buf[kIdxReverseLight] = 0;
      buf[kIdxMotorEn] = throttle.clamp(0, 255);
    }

    // Clamp all payload bytes to 0-254 so 0xFF never appears in payload
    for (int i = 0; i < kCmdBufLen; i++) {
      if (buf[i] == kStartByte) buf[i] = 0xFE;
    }

    // Prepend start byte for framing
    final framed = Uint8List(1 + kCmdBufLen);
    framed[0] = kStartByte;
    framed.setRange(1, 1 + kCmdBufLen, buf);

    return framed;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Arduino Telemetry Parser
// ══════════════════════════════════════════════════════════════════════════════

class ArduinoTelemetry {
  final double speed;
  final double batteryVoltage; // actual voltage (e.g. 12.34)
  final int batteryPercent;
  final int rpm;

  ArduinoTelemetry({
    required this.speed,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.rpm,
  });

  /// Parse telemetry data from Arduino format
  static ArduinoTelemetry? parse(dynamic data) {
    if (data is! List || data.length < kTelemBufLen) {
      return null;
    }

    try {
      final buf = List<int>.from(data);
      final adcCount = (buf[kTIdxBattInt] << 8) | buf[kTIdxBattDec];
      final voltage = (adcCount / 1023.0) * 12.0;
      final batteryPercent = buf[kTIdxBattPct].clamp(0, 100);
      final rpm = buf[kTIdxRpmLo] | (buf[kTIdxRpmHi] << 8);
      final speed = ((buf[kTIdxSpeedLo] << 8) | buf[kTIdxSpeedHi]) / 100.0;

      return ArduinoTelemetry(
        speed: speed,
        batteryVoltage: voltage,
        batteryPercent: batteryPercent,
        rpm: rpm,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'ArduinoTelemetry(speed: $speed m/s, battery: ${batteryVoltage.toStringAsFixed(2)}V, percent: $batteryPercent, rpm: $rpm)';
  }
}
