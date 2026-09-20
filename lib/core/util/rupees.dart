/// Whole rupees, grouped the Indian way: 124850 → 1,24,850.
///
/// Last three digits, then pairs. Held as an int end to end — a formatted
/// string like "₹4,200" loses the value, and a double loses the rupee.
String groupIndian(int rupees) {
  final s = rupees.abs().toString();
  final sign = rupees < 0 ? '-' : '';
  if (s.length <= 3) {
    return '$sign$s';
  }
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buffer = StringBuffer();
  // Walk the leading digits right-to-left in pairs.
  for (var i = rest.length; i > 0; i -= 2) {
    final start = i - 2 < 0 ? 0 : i - 2;
    buffer.write(rest.substring(start, i));
    if (start > 0) {
      buffer.write(',');
    }
  }
  final leading = buffer.toString().split(',').reversed.join(',');
  return '$sign$leading,$last3';
}

/// `1,24,850` → `₹1,24,850`.
String formatRupees(int rupees) => '₹${groupIndian(rupees)}';

const _zero = 0x30; // '0'
const _nine = 0x39; // '9'
const _comma = 0x2C; // ','
const _rupee = 0x20B9; // '₹'

bool _isDigit(int unit) => unit >= _zero && unit <= _nine;

/// Every digit in [raw], in order, and nothing else.
///
/// Done by code unit rather than a regex: this runs on every keystroke in the
/// amount field, and a pattern compiled per character to strip two separators
/// is work for nothing.
String digitsOf(String raw) {
  final out = StringBuffer();
  for (final unit in raw.codeUnits) {
    if (_isDigit(unit)) {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// True when [raw] contains only what this field renders: digits, the grouping
/// comma and the rupee sign. Anything else — a decimal point, a minus, a
/// letter — would change the amount if we stripped it, so callers reject it.
bool isRenderableAmount(String raw) {
  for (final unit in raw.runes) {
    if (!_isDigit(unit) && unit != _comma && unit != _rupee) {
      return false;
    }
  }
  return true;
}

/// Drops leading zeros, but keeps a lone `0`: that is a real amount of zero,
/// and the only value a numeric keypad can produce that is below the minimum.
String withoutLeadingZeros(String digits) {
  var i = 0;
  while (i < digits.length - 1 && digits.codeUnitAt(i) == _zero) {
    i++;
  }
  return digits.substring(i);
}

/// Keeps only the digits a numeric keyboard can produce.
int? parseRupees(String raw) {
  final digits = digitsOf(raw);
  if (digits.isEmpty) {
    return null;
  }
  return int.tryParse(digits);
}
