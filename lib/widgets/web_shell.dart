import 'package:funclash/common/common.dart';
import 'package:material_ui/material_ui.dart';

const webCanvasKey = ValueKey('web-canvas');

/// Holds the app at the desktop window's size in the middle of the page, so
/// the panel reaches the same view mode. The decoration around it is filler.
class WebShell extends StatelessWidget {
  const WebShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.surfaceContainerLowest,
            scheme.secondaryContainer,
          ],
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Material(
            shape: AppShape.md,
            clipBehavior: Clip.antiAlias,
            elevation: 12,
            child: _buildCanvas(context),
          ),
        ),
      ),
    );
  }

  /// A sheet measuring the tab instead of the canvas would size itself wrong.
  Widget _buildCanvas(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: defaultWindowSize,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        systemGestureInsets: EdgeInsets.zero,
        displayFeatures: const [],
      ),
      child: SizedBox.fromSize(
        key: webCanvasKey,
        size: defaultWindowSize,
        child: child,
      ),
    );
  }
}
