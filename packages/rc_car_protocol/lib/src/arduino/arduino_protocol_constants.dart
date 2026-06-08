class ArduinoProtocol {
  static const int baudRate = 115200;
  static const int commandStartByte = 0xFF;
  static const int telemetryStartByte = 0xFE;

  static const int commandBufferLength = 16;
  static const int telemetryBufferLength = 8;
}

class ArduinoCommandIndex {
  static const int headLight = 0;
  static const int fogLight = 1;
  static const int indicatorRight = 2;
  static const int indicatorLeft = 3;
  static const int reverseLight = 4;
  static const int brakeLight = 5;
  static const int horn = 6;
  static const int steering = 7;
  static const int motorEnable = 8;
  static const int motorIn1 = 9;
  static const int motorIn2 = 10;
}

class ArduinoTelemetryIndex {
  static const int batteryHigh = 0;
  static const int batteryLow = 1;
  static const int rpmHigh = 2;
  static const int rpmLow = 3;
  static const int speedHigh = 4;
  static const int speedLow = 5;
  static const int batteryPercent = 6;
}

class ArduinoPins {
  static const int rpmSensor = 2;
  static const int headLight = 3;
  static const int steering = 4;
  static const int brakeLight = 5;
  static const int fogLight = 6;
  static const int indicatorLeft = 7;
  static const int reverseLight = 8;
  static const int indicatorRight = 9;
  static const int motorIn1 = 10;
  static const int motorEnable = 11;
  static const int motorIn2 = 12;
  static const int batteryVoltageAnalog = 1;
}
