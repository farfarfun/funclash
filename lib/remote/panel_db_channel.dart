import 'dart:async';
import 'dart:typed_data';

import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:stream_channel/stream_channel.dart';

/// Buffered because drift subscribes late; JSON-safe because it sends bytes.
StreamChannel<Object?> panelDatabaseChannel(PanelSession session) {
  final controller = StreamChannelController<Object?>();
  final frames = session.databaseFrames.listen(
    (frame) => controller.foreign.sink.add(frame.payload),
    onDone: () => unawaited(controller.foreign.sink.close()),
  );
  controller.foreign.stream.listen(
    (message) => session.send(PanelFrame(PanelChannel.db, _encodable(message))),
    onDone: () => unawaited(frames.cancel()),
  );
  return controller.local;
}

Object? _encodable(Object? message) {
  if (message is Uint8List) {
    return message.toList(growable: false);
  }
  if (message is List) {
    return message.map(_encodable).toList(growable: false);
  }
  return message;
}
