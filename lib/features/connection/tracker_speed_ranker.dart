import 'dart:math';

import 'package:funclash/models/models.dart';

class _SpeedSample {
  final int upload;
  final int download;
  final DateTime at;
  final int uploadSpeed;
  final int downloadSpeed;
  final double rankSpeed;

  const _SpeedSample({
    required this.upload,
    required this.download,
    required this.at,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.rankSpeed,
  });
}

typedef _Ranked = ({
  int bucket,
  int position,
  int traffic,
  TrackerInfo trackerInfo,
});

/// Derives per-connection speed from successive cumulative snapshots and
/// orders connections by it without reshuffling the list every poll.
class TrackerSpeedRanker {
  // Closing a connection triggers an out-of-band refresh; a delta over a few
  // milliseconds would read as a spike, so such samples keep the last speed.
  static const _minSampleGap = Duration(milliseconds: 500);
  static const _smoothing = 0.5;

  final _samples = <String, _SpeedSample>{};
  var _positions = const <String, int>{};

  List<TrackerInfo> rank(List<TrackerInfo> trackerInfos, DateTime now) {
    final samples = <String, _SpeedSample>{
      for (final trackerInfo in trackerInfos)
        trackerInfo.id: _sample(trackerInfo, now),
    };
    _samples
      ..clear()
      ..addAll(samples);

    // Every key is read once here rather than from the comparator, which runs
    // a few thousand connections' worth of log() and lookups otherwise.
    final ranked = [
      for (final trackerInfo in trackerInfos)
        _rank(trackerInfo, samples[trackerInfo.id]!, trackerInfos.length),
    ]..sort(_compare);
    _positions = {
      for (final (index, row) in ranked.indexed) row.trackerInfo.id: index,
    };
    return [for (final row in ranked) row.trackerInfo];
  }

  _Ranked _rank(
    TrackerInfo trackerInfo,
    _SpeedSample sample,
    int unplacedPosition,
  ) {
    final speed = sample.rankSpeed;
    return (
      bucket: speed < 1 ? 0 : (log(speed) / ln2).floor() + 1,
      position: _positions[trackerInfo.id] ?? unplacedPosition,
      traffic: trackerInfo.upload + trackerInfo.download,
      trackerInfo: trackerInfo.copyWith(
        uploadSpeed: sample.uploadSpeed,
        downloadSpeed: sample.downloadSpeed,
      ),
    );
  }

  static int _compare(_Ranked a, _Ranked b) {
    final bucket = b.bucket.compareTo(a.bucket);
    if (bucket != 0) {
      return bucket;
    }
    if (a.bucket > 0) {
      final position = a.position.compareTo(b.position);
      if (position != 0) {
        return position;
      }
    }
    final traffic = b.traffic.compareTo(a.traffic);
    if (traffic != 0) {
      return traffic;
    }
    final start = b.trackerInfo.start.compareTo(a.trackerInfo.start);
    return start != 0 ? start : a.trackerInfo.id.compareTo(b.trackerInfo.id);
  }

  _SpeedSample _sample(TrackerInfo trackerInfo, DateTime now) {
    final previous = _samples[trackerInfo.id];
    if (previous == null) {
      return _SpeedSample(
        upload: trackerInfo.upload,
        download: trackerInfo.download,
        at: now,
        uploadSpeed: 0,
        downloadSpeed: 0,
        rankSpeed: 0,
      );
    }
    final elapsed = now.difference(previous.at);
    if (elapsed < _minSampleGap) {
      return previous;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final uploadSpeed = max(0, trackerInfo.upload - previous.upload) / seconds;
    final downloadSpeed =
        max(0, trackerInfo.download - previous.download) / seconds;
    final rankSpeed =
        previous.rankSpeed +
        (uploadSpeed + downloadSpeed - previous.rankSpeed) * _smoothing;
    return _SpeedSample(
      upload: trackerInfo.upload,
      download: trackerInfo.download,
      at: now,
      uploadSpeed: uploadSpeed.round(),
      downloadSpeed: downloadSpeed.round(),
      rankSpeed: rankSpeed < 1 ? 0 : rankSpeed,
    );
  }
}
