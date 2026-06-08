class ProtocolConstants {
  static const int startByte = 0xAA;
  static const int endByte = 0xBB;

  static const int typeCommand = 0x01;
  static const int typeResponse = 0x02;
  static const int typeTelemetry = 0x03;
  static const int typeHeartbeat = 0xFF;
}

class CommandIds {
  static const int pinMode = 0x10;
  static const int digitalWrite = 0x11;
  static const int analogWrite = 0x12;
  static const int reportDigital = 0x13;
  static const int reportAnalog = 0x14;
  static const int servoWrite = 0x15;
}

enum PinMode {
  input(0x00),
  output(0x01),
  pwm(0x02);

  final int value;
  const PinMode(this.value);
}
