import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_motion.dart';
import '../../core/design/fave_type.dart';

/// Slide up from fully below the screen, 250 ms, ease-out; scrim fades
/// 0 → 45% over the same 250 ms. Dismiss on scrim tap or a pick, reversed.
///
/// Written as a route rather than `showModalBottomSheet` so the duration, the
/// curve and the scrim opacity are the spec's numbers and not the framework's.
Future<T?> showFaveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => Navigator.of(
  context,
  rootNavigator: true,
).push(_FaveSheetRoute<T>(builder));

class _FaveSheetRoute<T> extends PopupRoute<T> {
  _FaveSheetRoute(this.builder);

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => FaveMotion.sheet;

  @override
  Duration get reverseTransitionDuration => FaveMotion.sheet;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  /// The scrim is animated by hand below, so the route's own barrier is clear.
  @override
  Color? get barrierColor => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: FaveMotion.sheetCurve,
      reverseCurve: FaveMotion.sheetCurve.flipped,
    );
    return Stack(
      children: [
        FadeTransition(
          opacity: eased,
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(
              color: FaveColors.scrim,
              child: SizedBox.expand(),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              // Fully below the screen.
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(eased),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Top radius 24 · 12 top / 24 sides / 32 bottom padding · grabber 36 × 4,
/// radius 2, centred, 10 beneath · 6 between blocks.
class FaveSheetShell extends StatelessWidget {
  const FaveSheetShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: FaveColors.screen,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FaveMetrics.sheetRadius),
      ),
    ),
    padding: EdgeInsets.only(
      top: FaveMetrics.sheetPadTop,
      left: FaveMetrics.sheetPadSide,
      right: FaveMetrics.sheetPadSide,
      bottom:
          FaveMetrics.sheetPadBottom + MediaQuery.viewPaddingOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: FaveMetrics.grabberWidth,
            height: FaveMetrics.grabberHeight,
            decoration: BoxDecoration(
              color: FaveColors.chipFill,
              borderRadius: BorderRadius.circular(FaveMetrics.grabberRadius),
            ),
          ),
        ),
        const SizedBox(height: FaveMetrics.grabberGap),
        Text(title, style: FaveType.screenTitle),
        const SizedBox(height: FaveMetrics.sheetBlockGap),
        Text(subtitle, style: FaveType.caption),
        const SizedBox(height: FaveMetrics.sheetBlockGap),
        ...children,
      ],
    ),
  );
}

/// 20 px. Selected: filled #5E6DFF with an 8 px white dot. Unselected:
/// 2 px #D3C8B8 border.
class FaveRadio extends StatelessWidget {
  const FaveRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: FaveMetrics.radioSize,
    height: FaveMetrics.radioSize,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? FaveColors.link : null,
      border: selected
          ? null
          : Border.all(
              color: FaveColors.chipBorder,
              width: FaveMetrics.radioBorder,
            ),
    ),
    child: selected
        ? Center(
            child: Container(
              width: FaveMetrics.radioDot,
              height: FaveMetrics.radioDot,
              decoration: const BoxDecoration(
                color: FaveColors.onTeal,
                shape: BoxShape.circle,
              ),
            ),
          )
        : null,
  );
}
