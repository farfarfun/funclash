import 'package:funclash/common/common.dart';
import 'package:funclash/icons/icons.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/state.dart';
import 'package:funclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _threeDigitHourThreshold = 100 * 60 * 60 * 1000;
const _widthAnimationDuration = Duration(milliseconds: 200);
const _buttonHeight = 56.0;
const _iconMorphDuration = Duration(milliseconds: 450);
const _sidebarLabelGap = 12.0;
const _sidebarIconSize = 24.0;
const _sidebarVerticalPadding = 2.0;
final _sidebarButtonShape = AppShape.all(10);

typedef _StartButtonPalette = ({Color background, Color foreground});

_StartButtonPalette _paletteOf(
  ColorScheme colorScheme, {
  required bool isStart,
  required bool suspended,
}) {
  if (suspended) {
    return (
      background: colorScheme.tertiaryContainer,
      foreground: colorScheme.onTertiaryContainer,
    );
  }
  if (isStart) {
    return (background: colorScheme.primary, foreground: colorScheme.onPrimary);
  }
  return (
    background: colorScheme.primaryContainer,
    foreground: colorScheme.onPrimaryContainer,
  );
}

TextStyle? _runTimeTextStyle(BuildContext context, {Color? color}) {
  return context.textTheme.titleMedium?.toSoftBold.copyWith(
    color: color ?? context.colorScheme.onPrimaryContainer,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

double _computeRunTimeTextWidth(
  BuildContext context, {
  required bool hasThreeDigitHours,
}) {
  final sample = hasThreeDigitHours ? '999:99:99' : '99:99:99';
  return globalState.measure
          .computeTextSize(Text(sample, style: _runTimeTextStyle(context)))
          .width +
      16;
}

class RunTimeText extends StatelessWidget {
  final int? timeStamp;
  final Color? color;

  const RunTimeText({super.key, required this.timeStamp, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      getTimeText(timeStamp),
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: _runTimeTextStyle(context, color: color),
    );
  }
}

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  double? _twoDigitTextWidth;
  double? _threeDigitTextWidth;
  double? _suspendedTextWidth;
  int? _displayRunTime;

  @override
  void initState() {
    super.initState();
    final isStart = ref.read(isStartProvider);
    _displayRunTime = ref.read(runTimeProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(runTimeProvider, (_, next) {
      _updateDisplayRunTime(next);
    });
    ref.listenManual(isStartProvider, (prev, next) {
      updateController(next);
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _twoDigitTextWidth = null;
    _threeDigitTextWidth = null;
    _suspendedTextWidth = null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void handleSwitchStart() {
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  void _updateDisplayRunTime(int? runTime) {
    if (!mounted ||
        _displayRunTime == runTime ||
        (runTime == null && !(_controller?.isDismissed ?? true))) {
      return;
    }
    setState(() {
      _displayRunTime = runTime;
    });
  }

  void updateController(bool isStart) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final controller = _controller;
      if (controller == null) {
        return;
      }
      if (isStart) {
        controller.forward();
        return;
      }
      controller.reverse().whenCompleteOrCancel(() {
        if (mounted && controller.isDismissed) {
          _updateDisplayRunTime(ref.read(runTimeProvider));
        }
      });
    });
  }

  double _getRunTimeTextWidth(
    BuildContext context, {
    required bool hasThreeDigitHours,
  }) {
    if (hasThreeDigitHours) {
      return _threeDigitTextWidth ??= _computeRunTimeTextWidth(
        context,
        hasThreeDigitHours: true,
      );
    }
    return _twoDigitTextWidth ??= _computeRunTimeTextWidth(
      context,
      hasThreeDigitHours: false,
    );
  }

  double _getSuspendedTextWidth(BuildContext context, String suspendedText) {
    return _suspendedTextWidth ??=
        globalState.measure
            .computeTextSize(
              Text(suspendedText, style: context.textTheme.titleMedium),
            )
            .width +
        24;
  }

  Widget _buildIcon(bool isStart, {required bool suspended}) {
    return AnimatedSwitcher(
      duration: context.motionDuration(commonDuration),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: suspended
          ? const GlyphIcon(AppGlyphs.wifiOff, fill: 1)
          : TweenAnimationBuilder<double>(
              tween: Tween(end: isStart ? 1 : 0),
              duration: _iconMorphDuration,
              curve: Curves.easeOutBack,
              builder: (_, progress, _) =>
                  GlyphIcon(AppGlyphs.playPause(progress), fill: 1),
            ),
    );
  }

  Widget _buildSidebarButton(
    BuildContext context,
    SidebarPaneScope scope, {
    required bool isStart,
    required bool suspended,
    required _StartButtonPalette palette,
  }) {
    final appLocalizations = context.appLocalizations;
    final expanded = scope.expanded && scope.progress == 1;
    final label = suspended
        ? appLocalizations.suspended
        : isStart
        ? getTimeText(_displayRunTime)
        : appLocalizations.start;
    final tooltip = expanded
        ? (isStart ? appLocalizations.stop : '')
        : suspended
        ? appLocalizations.suspended
        : isStart
        ? '${appLocalizations.stop} · ${getTimeText(_displayRunTime)}'
        : appLocalizations.start;
    final textStyle = context.textTheme.bodyMedium?.toSoftBold.copyWith(
      color: palette.foreground,
      fontFeatures: isStart && !suspended
          ? const [FontFeature.tabularFigures()]
          : null,
    );
    final overlay = WidgetStateProperty.fromMap({
      WidgetState.pressed: Colors.transparent,
      WidgetState.focused: palette.foreground.withValues(alpha: 0.1),
      WidgetState.hovered: palette.foreground.withValues(alpha: 0.08),
      WidgetState.any: Colors.transparent,
    });
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: scope.sideInset,
        vertical: _sidebarVerticalPadding,
      ),
      child: ElasticPress(
        child: Semantics(
          container: true,
          button: true,
          child: Material(
            color: palette.background,
            animationDuration: context.motionDuration(commonDuration),
            shape: _sidebarButtonShape,
            child: InkWell(
              onTap: handleSwitchStart,
              customBorder: _sidebarButtonShape,
              mouseCursor: SystemMouseCursors.click,
              splashFactory: NoSplash.splashFactory,
              overlayColor: overlay,
              child: Tooltip(
                message: tooltip,
                excludeFromSemantics: expanded && !isStart,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: _sidebarIconSize,
                    color: palette.foreground,
                  ),
                  child: SizedBox(
                    height: scope.itemHeight,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: AlignmentDirectional.centerStart,
                        minWidth: scope.rowWidth,
                        maxWidth: scope.rowWidth,
                        child: Row(
                          children: [
                            SizedBox(width: scope.iconInset),
                            _buildIcon(isStart, suspended: suspended),
                            const SizedBox(width: _sidebarLabelGap),
                            Expanded(
                              child: Opacity(
                                opacity: scope.labelOpacity,
                                alwaysIncludeSemantics: true,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle,
                                ),
                              ),
                            ),
                            const SizedBox(width: _sidebarLabelGap),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return Container();
    }
    final isStart = ref.watch(isStartProvider);
    final suspend = ref.watch(suspendProvider);
    final appLocalizations = context.appLocalizations;
    final suspended = isStart && suspend;
    final palette = _paletteOf(
      context.colorScheme,
      isStart: isStart,
      suspended: suspended,
    );
    final sidebarScope = SidebarPaneScope.maybeOf(context);
    if (sidebarScope != null) {
      return _buildSidebarButton(
        context,
        sidebarScope,
        isStart: isStart,
        suspended: suspended,
        palette: palette,
      );
    }
    final tooltip = suspended
        ? appLocalizations.suspended
        : isStart
        ? appLocalizations.stop
        : appLocalizations.start;
    if (NavigationDock.isDocked(context)) {
      return FloatingActionButton(
        heroTag: null,
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        tooltip: tooltip,
        onPressed: handleSwitchStart,
        child: _buildIcon(isStart, suspended: suspended),
      );
    }
    final hasThreeDigitHours =
        (_displayRunTime ?? 0) >= _threeDigitHourThreshold;
    final theme = Theme.of(context);
    final textWidth = suspend
        ? _getSuspendedTextWidth(context, appLocalizations.suspended)
        : _getRunTimeTextWidth(context, hasThreeDigitHours: hasThreeDigitHours);
    return RepaintBoundary(
      child: Theme(
        data: theme.copyWith(
          floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
            sizeConstraints: const BoxConstraints(
              minWidth: 56,
              maxWidth: 220,
              minHeight: _buttonHeight,
              maxHeight: _buttonHeight,
            ),
          ),
        ),
        child: ElasticButton(
          child: FloatingActionButton(
            clipBehavior: Clip.antiAlias,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            heroTag: null,
            backgroundColor: palette.background,
            foregroundColor: palette.foreground,
            tooltip: tooltip,
            onPressed: () {
              handleSwitchStart();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (_, child) {
                    return Container(
                      height: _buttonHeight,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16 - 8 * _animation.value,
                      ),
                      alignment: Alignment.centerLeft,
                      child: child,
                    );
                  },
                  child: _buildIcon(isStart, suspended: suspended),
                ),
                SizeTransition(
                  axis: Axis.horizontal,
                  alignment: Alignment.centerLeft,
                  sizeFactor: _animation,
                  child: AnimatedContainer(
                    width: textWidth,
                    duration: _widthAnimationDuration,
                    curve: Curves.easeOut,
                    child: suspend
                        ? Text(
                            appLocalizations.suspended,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: palette.foreground),
                          )
                        : RunTimeText(
                            timeStamp: _displayRunTime,
                            color: palette.foreground,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
