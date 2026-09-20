import 'package:fave_pay/core/design/fave_copy.dart';
import 'package:fave_pay/core/util/rupees.dart';
import 'package:fave_pay/domain/model/amount.dart';
import 'package:fave_pay/ui/widgets/pay_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Optional: grouping and the validation boundaries.
void main() {
  group('Indian grouping', () {
    test('last three digits, then pairs', () {
      expect(groupIndian(1), '1');
      expect(groupIndian(999), '999');
      expect(groupIndian(1000), '1,000');
      expect(groupIndian(4200), '4,200');
      expect(groupIndian(99999), '99,999');
      expect(groupIndian(100000), '1,00,000');
      expect(groupIndian(124850), '1,24,850');
      expect(groupIndian(1200000), '12,00,000');
      expect(groupIndian(12345678), '1,23,45,678');
    });

    test('formatRupees prefixes the symbol', () {
      expect(formatRupees(4200), '₹4,200');
    });
  });

  group('the field', () {
    const formatter = RupeeInputFormatter();

    TextEditingValue type(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('groups live as you type', () {
      expect(type('1').text, '₹1');
      expect(type('124').text, '₹124');
      expect(type('1248').text, '₹1,248');
      expect(type('124850').text, '₹1,24,850');
    });

    test('a leading zero goes', () {
      expect(type('04200').text, '₹4,200');
      expect(type('').text, '');
    });

    test('input that would change the amount is refused, not stripped', () {
      // A numeric keypad cannot produce these, but a paste can. Stripping the
      // offending characters silently changes what is being paid, so the edit
      // is rejected and the field keeps what it had.
      const existing = TextEditingValue(text: '₹4,200');
      TextEditingValue paste(String text) =>
          formatter.formatEditUpdate(existing, TextEditingValue(text: text));

      // ₹42.50 must never become ₹4,250 — a hundredfold error.
      expect(paste('42.50').text, existing.text);
      expect(paste('-1').text, existing.text);
      expect(paste('12abc34').text, existing.text);
      expect(paste('1 000').text, existing.text);
      expect(paste('4,2e3').text, existing.text);

      // A clean paste of whole rupees is still accepted.
      expect(paste('7500').text, '₹7,500');
      // And so is the field's own rendering, so typing still works.
      expect(paste('₹4,2001').text, '₹42,001');
    });

    test('a lone zero is a value, not an empty field', () {
      // Frame 01d. Nothing else you can type on a numeric keypad is under ₹1,
      // so collapsing `0` to empty would make below-minimum unreachable — the
      // field would show the grey ₹0 placeholder and no error at all.
      expect(type('0').text, '₹0');
      expect(type('00').text, '₹0');
      expect(parseRupees(type('0').text), 0);
      expect(
        AmountRules.validate(parseRupees(type('0').text)),
        isA<BelowMinimum>(),
      );
      expect(
        AmountRules.validate(parseRupees(type('0').text)).message,
        FaveCopy.errorBelowMinimum,
      );

      // And an empty field is still empty: placeholder, no error.
      expect(parseRupees(type('').text), isNull);
      expect(
        AmountRules.validate(parseRupees(type('').text)),
        isA<EmptyAmount>(),
      );
      expect(AmountRules.validate(parseRupees(type('').text)).message, isNull);
    });

    test('the cursor stays at the end so grouping never strands it', () {
      final value = type('124850');
      expect(value.selection.baseOffset, value.text.length);
    });
  });

  group('validation is a type', () {
    test('empty shows no error and cannot pay', () {
      const v = EmptyAmount();
      expect(AmountRules.validate(null), isA<EmptyAmount>());
      expect(v.message, isNull);
      expect(v.rupees, isNull);
    });

    test('the boundaries', () {
      expect(AmountRules.validate(0), isA<BelowMinimum>());
      expect(AmountRules.validate(1), isA<ValidAmount>());
      expect(AmountRules.validate(100000), isA<ValidAmount>());
      expect(AmountRules.validate(100001), isA<OverUpiLimit>());
    });

    test('the reasons carry the exact copy', () {
      expect(AmountRules.validate(0).message, FaveCopy.errorBelowMinimum);
      expect(AmountRules.validate(120000).message, FaveCopy.errorOverLimit);
      expect(AmountRules.validate(4200).message, isNull);
      expect(AmountRules.validate(4200).rupees, 4200);
    });
  });
}
