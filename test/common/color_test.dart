import 'package:funclash/common/color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/hct/hct.dart';

double _contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

void main() {
  test('neutral surfaces retain tonal hierarchy and chosen accent colors', () {
    for (final seed in [Colors.blue, Colors.pink, Colors.green, Colors.grey]) {
      for (final brightness in Brightness.values) {
        final original = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.content,
        );
        final scheme = original.toNeutralSurfaces();
        expect(scheme.primary, original.primary);
        expect(scheme.secondaryContainer, original.secondaryContainer);
        expect(scheme.tertiary, original.tertiary);
        final surfaces = [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ];
        final tones = surfaces
            .map((color) => Hct.fromInt(color.toARGB32()).tone)
            .toList();
        expect(
          tones,
          orderedEquals(
            brightness == Brightness.dark
                ? ([...tones]..sort())
                : ([...tones]..sort()).reversed,
          ),
        );
        for (final surface in surfaces) {
          expect(Hct.fromInt(surface.toARGB32()).chroma, lessThan(3));
          expect(_contrast(scheme.onSurface, surface), greaterThanOrEqualTo(7));
          expect(
            _contrast(scheme.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
  });

  test('status text stays readable on light, dark and pure black surfaces', () {
    for (final seed in [Colors.blue, Colors.pink, Colors.green, Colors.grey]) {
      for (final brightness in Brightness.values) {
        for (final pureBlack in [false, true]) {
          final scheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: brightness,
          ).toNeutralSurfaces().toPureBlack(pureBlack);
          for (final status in [scheme.success, scheme.warning]) {
            for (final surface in [
              scheme.surface,
              scheme.surfaceContainerLow,
              scheme.surfaceContainerHighest,
              Color.alphaBlend(status.opacity12, scheme.surface),
            ]) {
              expect(_contrast(status, surface), greaterThanOrEqualTo(4.5));
            }
          }
        }
      }
    }
  });

  test('opacity extensions use their named alpha values', () {
    const color = Colors.blue;
    const tolerance = 0.0001;

    expect(color.opacity80.a, closeTo(0.8, tolerance));
    expect(color.opacity50.a, closeTo(0.5, tolerance));
    expect(color.opacity10.a, closeTo(0.1, tolerance));
    expect(color.opacity3.a, closeTo(0.03, tolerance));
    expect(color.opacity0.a, 0);
  });
}
