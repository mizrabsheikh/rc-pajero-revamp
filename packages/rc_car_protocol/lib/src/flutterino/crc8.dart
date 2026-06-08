class Crc8 {
  static const int _polynomial = 0x07;

  static int compute(List<int> data) {
    var crc = 0x00;
    for (final byte in data) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = (crc << 1) ^ _polynomial;
        } else {
          crc <<= 1;
        }
      }
      crc &= 0xFF;
    }
    return crc;
  }
}
