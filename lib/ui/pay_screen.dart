import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/design/fave_colors.dart';
import '../core/time/clock.dart';
import '../core/util/rupees.dart';
import '../machine/payment_bloc.dart';
import '../machine/payment_event.dart';
import '../machine/payment_state.dart';
import 'screens/confirming_view.dart';
import 'screens/failed_view.dart';
import 'screens/pay_view.dart';
import 'screens/still_confirming_view.dart';
import 'screens/success_view.dart';
import 'sheets/backend_sheet.dart';
import 'sheets/recipient_sheet.dart';
import 'widgets/countdown_ring.dart';

/// The host. It owns the two text controllers, forwards the app's lifecycle,
/// opens the sheets — and otherwise does nothing but pick a view.
///
/// Every state the user can see is chosen by switching on a sealed class, so
/// this cannot forget a case. There are no timers and no polling here.
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.backendModes, required this.clock});

  final BackendModeController backendModes;
  final Clock clock;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> with WidgetsBindingObserver {
  final _fields = PayFields();

  PaymentBloc get _bloc => context.read<PaymentBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fields.amount.addListener(_onAmountChanged);
    _fields.note.addListener(_onNoteChanged);
    // The underline colour depends on focus, so a focus change is a repaint.
    _fields.amountFocus.addListener(_rebuild);
    _fields.noteFocus.addListener(_rebuild);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fields.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onAmountChanged() =>
      _bloc.add(AmountEdited(parseRupees(_fields.amount.text)));

  void _onNoteChanged() => _bloc.add(NoteEdited(_fields.note.text));

  /// B5 — produced by backgrounding the app, in any mode.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bloc.add(const AppResumed());
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FaveColors.screen,
    child: SafeArea(
      top: false,
      bottom: false,
      child: BlocListener<PaymentBloc, PaymentState>(
        // The form lives in the bloc and in two controllers. When the machine
        // clears it, the fields have to follow — otherwise the amount still
        // reads ₹4,200 while the CTA is disabled, which is worse than either.
        listenWhen: (before, after) => after is Editing,
        listener: (_, state) {
          if (state.form.amountRupees == null &&
              _fields.amount.text.isNotEmpty) {
            _fields.amount.clear();
          }
          if (state.form.note == null && _fields.note.text.isNotEmpty) {
            _fields.note.clear();
          }
        },
        child: BlocBuilder<PaymentBloc, PaymentState>(builder: _view),
      ),
    ),
  );

  Widget _view(BuildContext context, PaymentState state) => switch (state) {
    Editing() => _pay(state, sending: false),
    Sending() => _pay(state, sending: true),
    Confirming() => ConfirmingView(
      attempt: state.attempt,
      ring: CountdownRing.counting(
        clock: widget.clock,
        deadline: state.deadline,
      ),
    ),
    ConfirmingExit() => ConfirmingView(
      attempt: state.attempt,
      ring: CountdownRing.exiting(exitFrom: state.exitFrom),
    ),
    Succeeded() => SuccessView(
      state: state,
      now: widget.clock.now(),
      // The payment went through: do not leave it primed to send again.
      onDone: () => _bloc.add(const ReturnToPayTapped(clearForm: true)),
    ),
    PaymentFailed() => FailedView(
      onTryAgain: () => _bloc.add(const TryAgainTapped()),
      // Nothing left the account; keep what was typed.
      onGoBack: () => _bloc.add(const ReturnToPayTapped()),
    ),
    StillConfirming() => StillConfirmingView(
      checking: state.checking,
      // The money may still be in flight — the notice box says so. Priming
      // the same amount for a second send is what it warns against.
      onGoToHome: () => _bloc.add(const ReturnToPayTapped(clearForm: true)),
      onCheckStatus: () => _bloc.add(const CheckStatusTapped()),
    ),
  };

  Widget _pay(PaymentState state, {required bool sending}) => PayView(
    state: state,
    sending: sending,
    fields: _fields,
    chipLabel: widget.backendModes.chipLabel,
    now: widget.clock.now(),
    onChip: _openBackendSheet,
    onRecipient: () => _openRecipientSheet(state.form),
    onPay: () {
      FocusManager.instance.primaryFocus?.unfocus();
      _bloc.add(const PayTapped());
    },
  );

  // ------------------------------------------------------------- the sheets

  Future<void> _openBackendSheet() async {
    await showBackendSheet(context, widget.backendModes);
    if (mounted) {
      setState(() {}); // the chip reads the new mode
    }
  }

  Future<void> _openRecipientSheet(PayForm form) async {
    final picked = await showRecipientSheet(context, form.recipient);
    if (picked != null && mounted) {
      _bloc.add(RecipientPicked(picked));
    }
  }
}
