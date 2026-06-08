import 'package:rc_car_protocol/rc_car_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('builds framed Arduino command buffers', () {
    final command = ArduinoCommandBuilder.buildCommand(
      steering: 90,
      throttle: 300,
      motorIn1: true,
      motorIn2: false,
      headLight: true,
      highBeam: false,
      fogLight: true,
      indicatorLeft: false,
      indicatorRight: true,
      reverseLight: false,
      brakeLight: false,
      lowIntensityBrakeLight: true,
    );

    expect(command, hasLength(1 + ArduinoProtocol.commandBufferLength));
    expect(command.first, ArduinoProtocol.commandStartByte);
    expect(command[1 + ArduinoCommandIndex.headLight], 120);
    expect(command[1 + ArduinoCommandIndex.fogLight], 1);
    expect(command[1 + ArduinoCommandIndex.indicatorRight], 1);
    expect(command[1 + ArduinoCommandIndex.steering], 90);
    expect(command[1 + ArduinoCommandIndex.motorEnable], 254);
  });

  test('parses Arduino telemetry matching firmware byte order', () {
    final telemetry = ArduinoTelemetry.parse([
      0x01,
      0xFF,
      0x04,
      0xD2,
      0x00,
      0x7B,
      87,
      0,
    ]);

    expect(telemetry, isNotNull);
    expect(telemetry!.rpm, 1234);
    expect(telemetry.speed, 1.23);
    expect(telemetry.batteryPercent, 87);
  });

  test('serializes and parses Flutterino packets', () {
    final packet = Packet(
      msgType: ProtocolConstants.typeCommand,
      cmdId: CommandIds.digitalWrite,
      payload: [ArduinoPins.headLight, 1],
    );

    final parsed = Packet.parse(packet.toBytes());

    expect(parsed, isNotNull);
    expect(parsed!.msgType, ProtocolConstants.typeCommand);
    expect(parsed.cmdId, CommandIds.digitalWrite);
    expect(parsed.payload, [ArduinoPins.headLight, 1]);
  });
}
