import '../../core/design/fave_copy.dart';

/// Validation is a type, not a string. An amount is either valid or a named
/// reason it is not — widgets render reasons, they do not compute them.
sealed class AmountValidation {
  const AmountValidation();

  /// The CTA is enabled only for [ValidAmount].
  int? get rupees => switch (this) {
    ValidAmount(:final rupees) => rupees,
    _ => null,
  };

  /// Null when there is nothing to show under the underline. Empty shows no
  /// error even though it is not valid.
  String? get message => switch (this) {
    ValidAmount() => null,
    EmptyAmount() => null,
    BelowMinimum() => FaveCopy.errorBelowMinimum,
    OverUpiLimit() => FaveCopy.errorOverLimit,
  };
}

class ValidAmount extends AmountValidation {
  const ValidAmount(this.rupees);

  @override
  final int rupees;
}

class EmptyAmount extends AmountValidation {
  const EmptyAmount();
}

class BelowMinimum extends AmountValidation {
  const BelowMinimum();
}

class OverUpiLimit extends AmountValidation {
  const OverUpiLimit();
}

abstract final class AmountRules {
  static const minimumRupees = 1;
  static const maximumRupees = 100000;

  /// Whole rupees, held as an int. Never a double.
  static AmountValidation validate(int? rupees) {
    if (rupees == null) {
      return const EmptyAmount();
    }
    if (rupees < minimumRupees) {
      return const BelowMinimum();
    }
    if (rupees > maximumRupees) {
      return const OverUpiLimit();
    }
    return ValidAmount(rupees);
  }
}
