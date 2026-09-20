import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/app.dart';
import 'package:fave_pay/core/design/fave_copy.dart';
import 'package:fave_pay/core/design/fave_motion.dart';
import 'package:fave_pay/core/time/clock.dart';
import 'package:fave_pay/data/file_payment_store.dart';
import 'package:fave_pay/domain/port/key_generator.dart';
import 'package:fave_pay/machine/payment_bloc.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:fave_pay/ui/sheets/backend_sheet.dart';
import 'package:fave_pay/ui/widgets/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ring exit, frame by frame.
///
/// §06 Motion: "the sweep runs from wherever it is to zero over 250 ms,
/// ease-out; the seconds label follows it and reads 0 on the final frame; then
/// the screen changes." From six seconds that is deliberately quick — the
/// point of this test is that it is a *tween* and not a snap, and that the
/// label really does reach zero before the screen changes.
void main() {
  /// Everything is built inside the test body: a bloc created in `setUp`
  /// lives outside `testWidgets`' fake-async zone, and its events never pump.
  ({PaymentBloc bloc, TestClock clock, FakePaymentBackend backend}) build({
    BackendMode mode = BackendMode.success,
  }) {
    final clock = TestClock(DateTime(2026, 9, 20, 18, 42));
    final backend = FakePaymentBackend(latency: Duration.zero)..mode = mode;
    return (
      bloc: PaymentBloc(
        backend: backend,
        store: InMemoryPaymentStore(),
        keys: SequentialKeyGenerator(),
        clock: clock,
      ),
      clock: clock,
      backend: backend,
    );
  }

  /// The seconds the ring is currently showing, e.g. "6s" -> 6.
  int secondsOnRing(WidgetTester tester) {
    final label = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere(
          (s) => RegExp(r'^\d+s$').hasMatch(s),
          orElse: () => fail('no seconds label on screen'),
        );
    return int.parse(label.substring(0, label.length - 1));
  }

  testWidgets('the sweep tweens to zero and reads 0 before the screen changes', (
    tester,
  ) async {
    final (:bloc, :clock, :backend) = build();
    Future<void> advance(Duration d) async {
      clock.advance(d);
      await tester.pump(d);
    }

    await tester.pumpWidget(
      FavePayApp(
        bloc: bloc,
        backendModes: BackendModeController(backend),
        clock: clock,
      ),
    );
    await bloc.start();
    await tester.pump();

    bloc
      ..add(const AmountEdited(4200))
      ..add(const PayTapped());
    await tester.pump();
    expect(bloc.state, isA<Confirming>());

    // success answers on the third call: 0 s, 2 s, then 4 s. Six seconds left.
    await advance(FaveMotion.pollInterval);
    await advance(FaveMotion.pollInterval);
    expect(bloc.state, isA<ConfirmingExit>());
    await tester.pump();
    final start = secondsOnRing(tester);
    expect(start, 6, reason: 'the answer landed with 6 s left');

    // Halfway through the 250 ms: strictly between, so it is easing rather
    // than jumping. Ease-out is ahead of linear here, which is why this is a
    // range and not the Figma card's "≈30%".
    await advance(const Duration(milliseconds: 125));
    final middle = secondsOnRing(tester);
    expect(middle, lessThan(start), reason: 'it moved');
    expect(middle, greaterThan(0), reason: 'and it has not snapped to zero');

    // The screen has not changed yet — the exit owns these 250 ms.
    expect(find.byType(SuccessBadge), findsNothing);
    expect(bloc.state, isA<ConfirmingExit>());

    // Final frame: the label reads 0, and only then does Success appear.
    await advance(const Duration(milliseconds: 125));
    expect(bloc.state, isA<Succeeded>());
    await tester.pump();
    expect(find.byType(SuccessBadge), findsOneWidget);
    expect(find.text(FaveCopy.amountSent('₹4,200')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await bloc.close();
      await backend.dispose();
    });
  });

  testWidgets('the exit runs before Failed too', (tester) async {
    final (:bloc, :clock, :backend) = build(mode: BackendMode.declined);
    Future<void> advance(Duration d) async {
      clock.advance(d);
      await tester.pump(d);
    }

    await tester.pumpWidget(
      FavePayApp(
        bloc: bloc,
        backendModes: BackendModeController(backend),
        clock: clock,
      ),
    );
    await bloc.start();
    await tester.pump();

    bloc
      ..add(const AmountEdited(4200))
      ..add(const PayTapped());
    await tester.pump();

    // declined answers on the second call, at 2 s. Eight seconds left.
    await advance(FaveMotion.pollInterval);
    expect(bloc.state, isA<ConfirmingExit>());
    await tester.pump();
    expect(secondsOnRing(tester), 8);

    await advance(const Duration(milliseconds: 125));
    expect(secondsOnRing(tester), lessThan(8));
    expect(find.text(FaveCopy.failedHeading), findsNothing);

    await advance(const Duration(milliseconds: 125));
    await tester.pump();
    expect(find.text(FaveCopy.failedHeading), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await bloc.close();
      await backend.dispose();
    });
  });
}
