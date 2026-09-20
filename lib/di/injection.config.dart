// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:io' as _i497;

import 'package:fave_fake_backend/fave_fake_backend.dart' as _i998;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../core/time/clock.dart' as _i467;
import '../domain/port/key_generator.dart' as _i739;
import '../domain/port/payment_store.dart' as _i809;
import '../machine/payment_bloc.dart' as _i846;
import '../ui/sheets/backend_sheet.dart' as _i321;
import 'app_module.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    await gh.singletonAsync<_i497.Directory>(
      () => appModule.documents(),
      preResolve: true,
    );
    gh.lazySingleton<_i467.Clock>(() => appModule.clock());
    gh.lazySingleton<_i739.KeyGenerator>(() => appModule.keys());
    gh.lazySingleton<_i809.PaymentStore>(
      () => appModule.store(gh<_i497.Directory>()),
    );
    gh.lazySingleton<_i998.FakePaymentBackend>(
      () => appModule.fake(gh<_i497.Directory>()),
    );
    gh.lazySingleton<_i998.PaymentBackend>(
      () => appModule.backend(gh<_i998.FakePaymentBackend>()),
    );
    gh.lazySingleton<_i321.BackendModeController>(
      () => appModule.backendModes(gh<_i998.FakePaymentBackend>()),
    );
    gh.lazySingleton<_i846.PaymentBloc>(
      () => appModule.bloc(
        gh<_i998.PaymentBackend>(),
        gh<_i809.PaymentStore>(),
        gh<_i739.KeyGenerator>(),
        gh<_i467.Clock>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i460.AppModule {}
