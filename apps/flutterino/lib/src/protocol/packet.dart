import 'dart:typed_data';
import 'commands.dart';
import 'crc8.dart';

/// Represents a framed packet in the Flutterino protocol.
/// Packet Format: [START(AA)] [MSG_TYPE] [CMD_ID] [LENGTH] [PAYLOAD...] [CRC8] [END(BB)]
class Packet {
  final int msgType;
  final int cmdId;
  final List<int> payload;

  Packet({required this.msgType, required this.cmdId, required this.payload});

  /// Factory constructor to build a heartbeat packet (0xFF)
  factory Packet.heartbeat() {
    return Packet(
      msgType: ProtocolConstants.typeHeartbeat,
      cmdId: 0x00,
      payload: [],
    );
  }

  /// Serializes the packet into a byte array
  Uint8List toBytes() {
    final length = payload.length;
    // START, TYPE, CMD, LEN, PAYLOAD, CRC, END
    final buffer = BytesBuilder();

    buffer.addByte(ProtocolConstants.startByte);

    // Body starts here (used for CRC calculation)
    final body = <int>[msgType, cmdId, length, ...payload];
    buffer.add(body);

    // CRC8 over the body
    final crc = Crc8.compute(body);
    buffer.addByte(crc);

    buffer.addByte(ProtocolConstants.endByte);

    return buffer.toBytes();
  }

  /// Attempts to parse a packet from a raw byte buffer.
  /// Returns null if the packet is incomplete or invalid.
  static Packet? parse(List<int> buffer) {
    if (buffer.length < 6) {
      return null; // Minimum size: START, TYPE, CMD, LEN, CRC, END
    }

    if (buffer.first != ProtocolConstants.startByte) return null;

    int length = buffer[3];
    int expectedTotalLen = 6 + length;

    if (buffer.length < expectedTotalLen) return null; // Not enough data yet

    if (buffer[expectedTotalLen - 1] != ProtocolConstants.endByte) {
      // Invalid end byte, packet is corrupt.
      return null;
    }

    final msgType = buffer[1];
    final cmdId = buffer[2];
    final payload = buffer.sublist(4, 4 + length);

    final body = buffer.sublist(1, 4 + length);
    final expectedCrc = buffer[4 + length];

    final computedCrc = Crc8.compute(body);
    if (expectedCrc != computedCrc) {
      // CRC mismatch
      return null;
    }

    return Packet(msgType: msgType, cmdId: cmdId, payload: payload);
  }
}
