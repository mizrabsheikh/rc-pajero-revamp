import 'dart:typed_data';

import 'arduino_protocol_constants.dart';

class ArduinoCommandBuilder {
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
    final buf = Uint8List(ArduinoProtocol.commandBufferLength);

    buf[ArduinoCommandIndex.headLight] = highBeam
        ? 255
        : headLight
        ? 120
        : 0;
    buf[ArduinoCommandIndex.fogLight] = fogLight ? 1 : 0;
    buf[ArduinoCommandIndex.indicatorRight] = indicatorRight ? 1 : 0;
    buf[ArduinoCommandIndex.indicatorLeft] = indicatorLeft ? 1 : 0;
    buf[ArduinoCommandIndex.steering] = steering.clamp(0, 180);

    final brakeLightValue = brakeLight
        ? 254
        : lowIntensityBrakeLight
        ? 100
        : 0;

    if (brakeLight) {
      buf[ArduinoCommandIndex.motorEnable] = 255;
      buf[ArduinoCommandIndex.motorIn1] = 255;
      buf[ArduinoCommandIndex.motorIn2] = 255;
      buf[ArduinoCommandIndex.brakeLight] = brakeLightValue;
      buf[ArduinoCommandIndex.reverseLight] = 0;
    } else if (motorIn1 && !motorIn2) {
      buf[ArduinoCommandIndex.motorIn1] = 1;
      buf[ArduinoCommandIndex.motorIn2] = 0;
      buf[ArduinoCommandIndex.brakeLight] = brakeLightValue;
      buf[ArduinoCommandIndex.reverseLight] = 0;
      buf[ArduinoCommandIndex.motorEnable] = throttle.clamp(0, 255);
    } else if (!motorIn1 && motorIn2) {
      buf[ArduinoCommandIndex.motorIn1] = 0;
      buf[ArduinoCommandIndex.motorIn2] = 1;
      buf[ArduinoCommandIndex.reverseLight] = 1;
      buf[ArduinoCommandIndex.brakeLight] = brakeLightValue;
      buf[ArduinoCommandIndex.motorEnable] = throttle.clamp(0, 255);
    } else {
      buf[ArduinoCommandIndex.motorIn1] = 0;
      buf[ArduinoCommandIndex.motorIn2] = 0;
      buf[ArduinoCommandIndex.brakeLight] = brakeLightValue;
      buf[ArduinoCommandIndex.reverseLight] = reverseLight ? 1 : 0;
      buf[ArduinoCommandIndex.motorEnable] = throttle.clamp(0, 255);
    }

    for (var i = 0; i < ArduinoProtocol.commandBufferLength; i++) {
      if (buf[i] == ArduinoProtocol.commandStartByte) {
        buf[i] = ArduinoProtocol.telemetryStartByte;
      }
    }

    final framed = Uint8List(1 + ArduinoProtocol.commandBufferLength);
    framed[0] = ArduinoProtocol.commandStartByte;
    framed.setRange(1, 1 + ArduinoProtocol.commandBufferLength, buf);

    return framed;
  }
}
