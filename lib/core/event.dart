import 'dart:async';

import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';
import 'package:flutter/foundation.dart';

List<CoreEvent> coreEventsFromData(Object? data) {
  final items = data is List ? data : [data];
  final events = <CoreEvent>[];
  for (final item in items.whereType<Map>()) {
    try {
      events.add(CoreEvent.fromJson(Map<String, Object?>.from(item)));
    } catch (error) {
      commonPrint.log(
        'Unable to parse Core event: $error',
        logLevel: LogLevel.error,
      );
    }
  }
  return events;
}

abstract mixin class CoreEventListener {
  void onLog(Log log) {}

  void onDelay(Delay delay) {}

  void onRequest(TrackerInfo connection) {}

  void onDns(DnsQuery dnsQuery) {}

  void onLoaded(String providerName) {}

  void onCrash(String message) {}

  void onGeoUpdate(
    String geoType,
    bool updating,
    bool skipped,
    String? error,
  ) {}

  void onRouteChanged(RouteSnapshot snapshot) {}

  void onDialerLoop(String proxyName) {}
}

class CoreEventManager {
  // Broadcast so an observer can watch the raw events beside the typed fan-out
  // below. Nothing is buffered for a late subscriber either way: the
  // constructor is what listens.
  final _controller = StreamController<CoreEvent>.broadcast();

  CoreEventManager._() {
    _controller.stream.listen(_dispatch);
  }

  void _dispatch(CoreEvent event) {
    if (_listeners.isEmpty) {
      return;
    }
    final void Function(CoreEventListener listener) deliver;
    try {
      deliver = _buildDelivery(event);
    } catch (error) {
      commonPrint.log(
        'Unable to dispatch Core event ${event.type.name}: $error',
        logLevel: LogLevel.error,
      );
      return;
    }
    for (final CoreEventListener listener in List.of(_listeners)) {
      try {
        deliver(listener);
      } catch (error) {
        commonPrint.log(
          'Unable to dispatch Core event ${event.type.name}: $error',
          logLevel: LogLevel.error,
        );
      }
    }
  }

  void Function(CoreEventListener listener) _buildDelivery(CoreEvent event) {
    switch (event.type) {
      case CoreEventType.log:
        final log = Log.fromJson(event.data);
        return (listener) => listener.onLog(log);
      case CoreEventType.delay:
        final delay = Delay.fromJson(event.data);
        return (listener) => listener.onDelay(delay);
      case CoreEventType.request:
        final request = TrackerInfo.fromJson(event.data);
        return (listener) => listener.onRequest(request);
      case CoreEventType.dns:
        final dnsQuery = DnsQuery.fromJson(event.data);
        return (listener) => listener.onDns(dnsQuery);
      case CoreEventType.loaded:
        final providerName = event.data as String;
        return (listener) => listener.onLoaded(providerName);
      case CoreEventType.crash:
        final message = event.data as String;
        return (listener) => listener.onCrash(message);
      case CoreEventType.geoUpdate:
        final data = event.data as Map<String, dynamic>;
        final type = data['type'] as String;
        final updating = data['updating'] as bool;
        final skipped = data['skipped'] as bool? ?? false;
        final error = data['error'] as String?;
        return (listener) =>
            listener.onGeoUpdate(type, updating, skipped, error);
      case CoreEventType.routeChanged:
        final snapshot = RouteSnapshot.fromJson(
          Map<String, Object?>.from(event.data),
        );
        return (listener) => listener.onRouteChanged(snapshot);
      case CoreEventType.dialerLoop:
        final proxyName = event.data as String;
        return (listener) => listener.onDialerLoop(proxyName);
    }
  }

  static final CoreEventManager instance = CoreEventManager._();

  final ObserverList<CoreEventListener> _listeners =
      ObserverList<CoreEventListener>();

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  Stream<CoreEvent> get events => _controller.stream;

  void sendEvent(CoreEvent event) {
    _controller.add(event);
  }

  void addListener(CoreEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CoreEventListener listener) {
    _listeners.remove(listener);
  }
}

final coreEventManager = CoreEventManager.instance;
