import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import 'fave_sheet.dart';

/// This file and the tests are the only two places that know [BackendMode]
/// exists. The state machine only ever sees `PaymentBackend`.
///
/// The app never tells the backend a mode per call: this sets `backend.mode`
/// once, and the fake captures it per key when create is called — so a mode
/// picked here applies to the next attempt only, including a Try again.
class BackendModeController extends ValueNotifier<BackendMode> {
  BackendModeController(this._backend) : super(_backend.mode);

  final FakePaymentBackend _backend;

  @override
  set value(BackendMode mode) {
    _backend.mode = mode;
    super.value = mode;
  }

  /// What the chip in Pay's top bar reads.
  String get chipLabel => _options.firstWhere((o) => o.mode == value).chipLabel;
}

class _ModeOption {
  const _ModeOption(this.mode, this.name, this.chipLabel, this.description);

  final BackendMode mode;
  final String name;
  final String chipLabel;
  final String description;
}

/// Six modes, in the sheet's order. B5 is not a mode — you produce it by
/// backgrounding the app, which is why the subtitle says so.
const _options = <_ModeOption>[
  _ModeOption(
    BackendMode.success,
    'Success',
    'Success',
    'pending, pending, success — about 4 s',
  ),
  _ModeOption(BackendMode.declined, 'Declined', 'Declined', 'pending, failed'),
  _ModeOption(
    BackendMode.lostResponse,
    'B1 · Lost response',
    'B1',
    'create hangs; status(key) says pending, then success',
  ),
  _ModeOption(
    BackendMode.pendingForever,
    'B2 · Pending forever',
    'B2',
    'pending, pending, pending…',
  ),
  _ModeOption(
    BackendMode.flipAfterSuccess,
    'B3 · Flip after success',
    'B3',
    'pending, success · push: failed, 300 ms later',
  ),
  _ModeOption(
    BackendMode.lateSuccess,
    'B4 · Late success',
    'B4',
    'pending, failed · push: success, 2 min later',
  ),
];

Future<void> showBackendSheet(
  BuildContext context,
  BackendModeController controller,
) => showFaveSheet<void>(
  context: context,
  builder: (sheetContext) => ValueListenableBuilder<BackendMode>(
    valueListenable: controller,
    builder: (_, selected, _) => FaveSheetShell(
      title: FaveCopy.backendSheetTitle,
      subtitle: FaveCopy.backendSheetSubtitle,
      children: [
        for (final option in _options)
          _ModeRow(
            option: option,
            selected: option.mode == selected,
            onTap: () {
              controller.value = option.mode;
              Navigator.of(sheetContext).maybePop();
            },
          ),
      ],
    ),
  ),
);

/// 9 vertical padding · 14 gap · radio 20.
class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: FaveMetrics.sheetRowPadV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaveRadio(selected: selected),
          const SizedBox(width: FaveMetrics.sheetRowGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(option.name, style: FaveType.sheetModeName),
                Text(option.description, style: FaveType.sheetModeDescription),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
