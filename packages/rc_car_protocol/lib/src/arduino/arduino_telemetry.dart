import 'arduino_protocol_constants.dart';

class ArduinoTelemetry {
  final double speed;
  final double batteryVoltage;
  final int batteryPercent;
  final int rpm;

  const ArduinoTelemetry({
    required this.speed,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.rpm,
  });

  static ArduinoTelemetry? parse(dynamic data) {
    if (data is! List || data.length < ArduinoProtocol.telemetryBufferLength) {
      return null;
    }

    try {
      final buf = List<int>.from(data);
      final adcCount =
          (buf[ArduinoTelemetryIndex.batteryHigh] << 8) |
          buf[ArduinoTelemetryIndex.batteryLow];
      final voltage = (adcCount / 1023.0) * 12.0;
      final batteryPercent = buf[ArduinoTelemetryIndex.batteryPercent].clamp(
        0,
        100,
      );
      final rpm =
          (buf[ArduinoTelemetryIndex.rpmHigh] << 8) |
          buf[ArduinoTelemetryIndex.rpmLow];
      final speed =
          ((buf[ArduinoTelemetryIndex.speedHigh] << 8) |
              buf[ArduinoTelemetryIndex.speedLow]) /
          100.0;

      return ArduinoTelemetry(
        speed: speed,
        batteryVoltage: voltage,
        batteryPercent: batteryPercent,
        rpm: rpm,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    return 'ArduinoTelemetry(speed: $speed m/s, battery: ${batteryVoltage.toStringAsFixed(2)}V, percent: $batteryPercent, rpm: $rpm)';
  }
}
