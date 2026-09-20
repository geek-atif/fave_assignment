import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/app.dart';
import 'package:fave_pay/core/design/fave_copy.dart';
import 'package:fave_pay/core/design/fave_motion.dart';
import 'package:fave_pay/core/time/clock.dart';
import 'package:fave_pay/data/file_payment_store.dart';
import 'package:fave_pay/domain/port/key_generator.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_bloc.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:fave_pay/ui/sheets/backend_sheet.dart';
import 'package:fave_pay/ui/widgets/badges.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The badge entrance is 600 ms. B3's push lands 300 ms after the success
/// poll — 50 ms in. This is the only test that pumps a widget, because the
/// claim being checked is about what is on screen while something animates.
void main() {
  testWidgets(
    'the success badge is interrupted and the screen ends on Failed',
    (tester) async {
      final clock = TestClock(DateTime(2026, 9, 19, 18, 42));
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.flipAfterSuccess;
      final bloc = PaymentBloc(
        backend: backend,
        store: InMemoryPaymentStore(),
        keys: SequentialKeyGenerator(),
        clock: clock,
      );

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

      // The app gates Pay on the launch restore; do what main() does.
      await bloc.start();
      await tester.pump();

      bloc
        ..add(const AmountEdited(4200))
        ..add(const PayTapped());
      await tester.pump();
      expect(bloc.state, isA<Confirming>());

      // Second poll says success; the ring runs to zero, then Success paints.
      await advance(FaveMotion.pollInterval);
      await advance(FaveMotion.ringExit);
      expect(find.byType(SuccessBadge), findsOneWidget);
      expect(find.text(FaveCopy.amountSent('₹4,200')), findsOneWidget);

      // 50 ms in: the badge is mid-entrance — scaled and not yet opaque.
      await advance(const Duration(milliseconds: 40));
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SuccessBadge),
          matching: find.byType(FadeTransition),
        ),
      );
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(SuccessBadge),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(
        fade.opacity.value,
        inExclusiveRange(0.0, 1.0),
        reason: 'the entrance really is still running',
      );
      expect(
        scale.scale.value,
        inExclusiveRange(FaveMotion.badgeFromScale, 1.0),
      );

      // The push lands. 300 ms after the success poll.
      await advance(const Duration(milliseconds: 10));

      expect(find.byType(SuccessBadge), findsNothing);
      expect(find.text(FaveCopy.amountSent('₹4,200')), findsNothing);
      expect(find.text(FaveCopy.failedHeading), findsOneWidget);
      expect(find.text(FaveCopy.failedSubline), findsOneWidget);

      // Let the rest of the 600 ms run: nothing paints twice, nothing throws.
      await advance(FaveMotion.badgeIn);
      expect(find.text(FaveCopy.failedHeading), findsOneWidget);
      expect(bloc.state, isA<PaymentFailed>());

      // Unmount first, then tear down outside the fake-async zone: the state
      // stream's done event is delivered on a microtask the pump loop owns.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await bloc.close();
        await backend.dispose();
      });
    },
  );
}
