import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/time/clock.dart';
import 'di/injection.dart';
import 'machine/payment_bloc.dart';
import 'ui/sheets/backend_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolves the documents directory before anything downstream needs it, so
  // every other registration is synchronous. The graph itself lives in
  // lib/di/app_module.dart.
  await configureDependencies();

  final bloc = getIt<PaymentBloc>();

  // Any record that never reached a terminal state gets one status(key).
  unawaited(bloc.start());

  runApp(
    FavePayApp(
      bloc: bloc,
      backendModes: getIt<BackendModeController>(),
      clock: getIt<Clock>(),
    ),
  );
}
