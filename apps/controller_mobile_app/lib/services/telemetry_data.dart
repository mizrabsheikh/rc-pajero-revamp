// ══════════════════════════════════════════════════════════════════════════════
// Telemetry Data Model
// ══════════════════════════════════════════════════════════════════════════════
// Generic telemetry data structure used by the socket service
// ══════════════════════════════════════════════════════════════════════════════

class TelemetryData {
  final double speed;
  final double batteryVoltage;
  final int batteryPercent;
  final int rpm;
  final int ambientLight;

  TelemetryData(
    this.speed,
    this.batteryVoltage,
    this.batteryPercent,
    this.rpm,
    this.ambientLight,
  );

  @override
  String toString() {
    return 'TelemetryData(speed: $speed, battery: $batteryVoltage, percent: $batteryPercent, ambient: $ambientLight)';
  }
}
