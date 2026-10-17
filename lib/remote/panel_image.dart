import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:funclash/remote/panel_file_bridge.dart';
import 'package:funclash/remote/panel_file_client.dart';

/// `FileImage` for a file system that answers over a bridge.
@immutable
final class PanelImage extends ImageProvider<PanelImage> {
  const PanelImage(this.path, {this.scale = 1.0});

  final String path;
  final double scale;

  @override
  Future<PanelImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<PanelImage>(this);

  @override
  ImageStreamCompleter loadImage(PanelImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.path,
    );
  }

  Future<ui.Codec> _load(PanelImage key, ImageDecoderCallback decode) async {
    final bytes = panelBytes(
      await panelFiles.call<Object>('readPathAsBytes', {'path': key.path}),
    );
    if (bytes.isEmpty) {
      throw StateError('the host returned no bytes for ${key.path}');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanelImage && other.path == path && other.scale == scale;

  @override
  int get hashCode => Object.hash(path, scale);

  @override
  String toString() => 'PanelImage("$path", scale: $scale)';
}
