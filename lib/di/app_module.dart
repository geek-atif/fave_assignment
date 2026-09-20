import 'dart:io';

import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../core/time/clock.dart';
import '../data/file_payment_store.dart';
import '../domain/port/key_generator.dart';
import '../domain/port/payment_store.dart';
import '../machine/payment_bloc.dart';
import '../ui/sheets/backend_sheet.dart';

/// The composition root, and the only place in the app that names the fake.
///
/// Everything is registered here rather than by annotating the classes
/// themselves. That is deliberate: `PaymentBloc`, `FilePaymentStore`,
/// `SystemClock` and the ports stay free of `package:injectable`, so the
/// machine is still plain Dart that a test constructs by hand. A DI container
/// is a wiring detail of the app — it should not reach into the domain.
@module
abstract class AppModule {
  /// Async, so it is resolved before `runApp`. Everything below is sync.
  @preResolve
  @singleton
  Future<Directory> documents() => getApplicationDocumentsDirectory();

  /// Our records live in our own file. The backend's store is the backend's —
  /// separate files are the only way to hold a record for a key it has
  /// forgotten.
  @lazySingleton
  PaymentStore store(Directory documents) =>
      FilePaymentStore('${documents.path}/fave_payments.json');

  /// The one instance of the fake. Registered as the concrete type only so the
  /// Backend behaviour sheet can set `mode`; nothing else resolves it.
  @lazySingleton
  FakePaymentBackend fake(Directory documents) =>
      FakePaymentBackend(storePath: '${documents.path}/backend_payments.json');

  /// What the rest of the app resolves. The machine only ever sees this type,
  /// and swapping the implementation is a one-line change here.
  @lazySingleton
  PaymentBackend backend(FakePaymentBackend fake) => fake;

  @lazySingleton
  Clock clock() => const SystemClock();

  @lazySingleton
  KeyGenerator keys() => RandomKeyGenerator();

  /// The sheet's handle on the fake — the second and last place that knows it
  /// exists.
  @lazySingleton
  BackendModeController backendModes(FakePaymentBackend fake) =>
      BackendModeController(fake);

  /// One bloc for the app's lifetime: there is one flow and one screen.
  @lazySingleton
  PaymentBloc bloc(
    PaymentBackend backend,
    PaymentStore store,
    KeyGenerator keys,
    Clock clock,
  ) => PaymentBloc(backend: backend, store: store, keys: keys, clock: clock);
}
