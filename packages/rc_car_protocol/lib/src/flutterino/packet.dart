import 'dart:typed_data';

import 'commands.dart';
import 'crc8.dart';

class Packet {
  final int msgType;
  final int cmdId;
  final List<int> payload;

  const Packet({
    required this.msgType,
    required this.cmdId,
    required this.payload,
  });

  factory Packet.heartbeat() {
    return const Packet(
      msgType: ProtocolConstants.typeHeartbeat,
      cmdId: 0x00,
      payload: [],
    );
  }

  Uint8List toBytes() {
    final buffer = BytesBuilder();
    final body = <int>[msgType, cmdId, payload.length, ...payload];

    buffer.addByte(ProtocolConstants.startByte);
    buffer.add(body);
    buffer.addByte(Crc8.compute(body));
    buffer.addByte(ProtocolConstants.endByte);

    return buffer.toBytes();
  }

  static Packet? parse(List<int> buffer) {
    if (buffer.length < 6) {
      return null;
    }

    if (buffer.first != ProtocolConstants.startByte) return null;

    final length = buffer[3];
    final expectedTotalLength = 6 + length;

    if (buffer.length < expectedTotalLength) return null;

    if (buffer[expectedTotalLength - 1] != ProtocolConstants.endByte) {
      return null;
    }

    final payload = buffer.sublist(4, 4 + length);
    final body = buffer.sublist(1, 4 + length);
    final expectedCrc = buffer[4 + length];

    if (expectedCrc != Crc8.compute(body)) {
      return null;
    }

    return Packet(msgType: buffer[1], cmdId: buffer[2], payload: payload);
  }
}
