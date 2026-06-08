// Implementation of modern CRC8 calculation
class Crc8 {
  static const int _polynomial = 0x07;

  static int compute(List<int> data) {
    int crc = 0x00;
    for (int i = 0; i < data.length; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x80) != 0) {
          crc = (crc << 1) ^ _polynomial;
        } else {
          crc <<= 1;
        }
      }
      crc &= 0xFF; // Keep it 8-bit
    }
    return crc;
  }
}
