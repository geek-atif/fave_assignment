import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/design/fave_colors.dart';
import 'core/design/fave_type.dart';
import 'core/time/clock.dart';
import 'machine/payment_bloc.dart';
import 'ui/pay_screen.dart';
import 'ui/sheets/backend_sheet.dart';

/// One screen, one navigator — the sheets are routes on it. No Material
/// theming: every colour and every type role comes from the design tokens.
class FavePayApp extends StatelessWidget {
  const FavePayApp({
    super.key,
    required this.bloc,
    required this.backendModes,
    required this.clock,
  });

  final PaymentBloc bloc;
  final BackendModeController backendModes;
  final Clock clock;

  @override
  Widget build(BuildContext context) => BlocProvider<PaymentBloc>.value(
    value: bloc,
    child: WidgetsApp(
      title: 'Fave',
      color: FaveColors.teal,
      textStyle: FaveType.body,
      // A single page; the sheets push on top of it.
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
      home: PayScreen(backendModes: backendModes, clock: clock),
    ),
  );
}
