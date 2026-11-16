class ThaiBahtText {
  ThaiBahtText._();

  static const List<String> _digits = [
    'ศูนย์',
    'หนึ่ง',
    'สอง',
    'สาม',
    'สี่',
    'ห้า',
    'หก',
    'เจ็ด',
    'แปด',
    'เก้า',
  ];

  static const List<String> _units = [
    '',
    'สิบ',
    'ร้อย',
    'พัน',
    'หมื่น',
    'แสน',
  ];

  /// Converts a non-negative Baht amount into standard Thai accounting words,
  /// e.g. `13800.00` -> `หนึ่งหมื่นสามพันแปดร้อยบาทถ้วน`,
  /// `13899.30` -> `หนึ่งหมื่นสามพันแปดร้อยเก้าสิบเก้าบาทสามสิบสตางค์`.
  static String convert(double amount) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      return 'ศูนย์บาทถ้วน';
    }

    final totalSatang = (amount * 100.0).round();
    final baht = totalSatang ~/ 100;
    final satang = totalSatang % 100;

    final bahtText = baht == 0 ? 'ศูนย์' : _readInteger(baht);
    if (satang == 0) {
      return '$bahtTextบาทถ้วน';
    }
    final satangText = _readInteger(satang);
    return '$bahtTextบาท$satangTextสตางค์';
  }

  static String _readInteger(int number) {
    if (number == 0) return 'ศูนย์';
    final s = number.toString();
    final len = s.length;
    final buf = StringBuffer();

    for (int i = 0; i < len; i++) {
      final d = s.codeUnitAt(i) - 48;
      final posFromRight = len - 1 - i;
      final modPos = posFromRight % 6;

      if (d != 0) {
        if (modPos == 1 && d == 1) {
          // 10 -> สิบ (not หนึ่งสิบ)
        } else if (modPos == 1 && d == 2) {
          buf.write('ยี่');
        } else if (modPos == 0 && d == 1 && i > 0) {
          // Check if any higher digit in the current 6-digit million-group is non-zero
          bool hasHigherInGroup = false;
          for (int k = 1; k <= 5 && (i - k) >= 0; k++) {
            if (s.codeUnitAt(i - k) != 48) {
              hasHigherInGroup = true;
              break;
            }
          }
          buf.write(hasHigherInGroup ? 'เอ็ด' : 'หนึ่ง');
        } else {
          buf.write(_digits[d]);
        }
        buf.write(_units[modPos]);
      }

      if (posFromRight > 0 && modPos == 0) {
        buf.write('ล้าน');
      }
    }

    return buf.toString();
  }
}
