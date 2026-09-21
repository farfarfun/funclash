import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/connection.dart';
import '../models/proxy.dart';
import '../models/traffic.dart';

/// mihomo 控制器 API 的地址和认证 secret；协议见
/// https://wiki.metacubex.one/api/。
class MihomoEndpoint {
  final String host;
  final int port;
  final String secret;
  final bool useTls;

  const MihomoEndpoint({
    required this.host,
    this.port = 9090,
    this.secret = '',
    this.useTls = false,
  });

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri(
      scheme: useTls ? 'https' : 'http',
      host: host,
      port: port,
      path: path,
      queryParameters: query,
    );
  }

  Uri _wsUri(String path, [Map<String, String>? query]) {
    return Uri(
      scheme: useTls ? 'wss' : 'ws',
      host: host,
      port: port,
      path: path,
      queryParameters: {if (secret.isNotEmpty) 'token': secret, ...?query},
    );
  }
}

/// mihomo 控制器返回非成功 HTTP 状态时抛出的异常。
class MihomoApiException implements Exception {
  final int? statusCode;
  final String message;

  /// 创建异常；[message] 是控制器响应内容，[statusCode] 可能为空。
  MihomoApiException(this.message, {this.statusCode});

  @override
  String toString() => 'MihomoApiException($statusCode): $message';
}

/// mihomo 控制器 REST/WebSocket API 的轻量客户端。
class MihomoApiClient {
  final MihomoEndpoint endpoint;
  final http.Client _http;

  MihomoApiClient(this.endpoint, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (endpoint.secret.isNotEmpty) 'Authorization': 'Bearer ${endpoint.secret}',
      };

  Future<T> _get<T>(String path, T Function(dynamic) parse, {Map<String, String>? query}) async {
    final res = await _http.get(endpoint._uri(path, query), headers: _headers);
    _checkOk(res);
    return parse(jsonDecode(res.body));
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MihomoApiException(res.body, statusCode: res.statusCode);
    }
  }

  /// 获取 mihomo 版本号；控制器缺少版本字段时返回 `unknown`。
  Future<String> getVersion() =>
      _get('/version', (json) => (json as Map<String, dynamic>)['version'] as String? ?? 'unknown');

  /// 获取当前代理和代理组，键为 mihomo 返回的名称。
  Future<Map<String, Proxy>> getProxies() {
    return _get('/proxies', (json) {
      final proxies = (json as Map<String, dynamic>)['proxies'] as Map<String, dynamic>? ?? {};
      return proxies.map((name, value) => MapEntry(name, Proxy.fromJson(name, value as Map<String, dynamic>)));
    });
  }

  /// 将代理组 [groupName] 的当前节点切换为 [proxyName]。
  Future<void> selectProxy(String groupName, String proxyName) async {
    final res = await _http.put(
      endpoint._uri('/proxies/${Uri.encodeComponent(groupName)}'),
      headers: _headers,
      body: jsonEncode({'name': proxyName}),
    );
    _checkOk(res);
  }

  /// 测试 [proxyName] 的延迟，返回毫秒数。
  Future<int> testDelay(
    String proxyName, {
    String testUrl = 'https://www.gstatic.com/generate_204',
    int timeoutMs = 5000,
  }) {
    return _get(
      '/proxies/${Uri.encodeComponent(proxyName)}/delay',
      (json) => (json as Map<String, dynamic>)['delay'] as int? ?? -1,
      query: {'url': testUrl, 'timeout': '$timeoutMs'},
    );
  }

  /// 获取当前连接快照。
  Future<ConnectionsSnapshot> getConnections() =>
      _get('/connections', (json) => ConnectionsSnapshot.fromJson(json as Map<String, dynamic>));

  /// 关闭指定连接；[id] 是 mihomo 返回的连接标识。
  Future<void> closeConnection(String id) async {
    final res = await _http.delete(endpoint._uri('/connections/${Uri.encodeComponent(id)}'), headers: _headers);
    _checkOk(res);
  }

  /// 关闭当前全部连接。
  Future<void> closeAllConnections() async {
    final res = await _http.delete(endpoint._uri('/connections'), headers: _headers);
    _checkOk(res);
  }

  /// 通过 `PUT /configs` payload 模式将 YAML 直接发送到运行中的 mihomo。
  Future<void> applyConfigPayload(String yaml) async {
    final res = await _http.put(
      endpoint._uri('/configs'),
      headers: _headers,
      body: jsonEncode({'path': '', 'payload': yaml}),
    );
    _checkOk(res);
  }

  /// 持续读取 `/traffic` WebSocket 的流量采样，取消订阅后结束。
  Stream<Traffic> watchTraffic() {
    final channel = WebSocketChannel.connect(endpoint._wsUri('/traffic'));
    return channel.stream.map((event) => Traffic.fromJson(jsonDecode(event as String) as Map<String, dynamic>));
  }

  /// 持续读取 `/logs` WebSocket 的日志行，取消订阅后结束。
  Stream<String> watchLogs({String level = 'info'}) {
    final channel = WebSocketChannel.connect(endpoint._wsUri('/logs', {'level': level}));
    return channel.stream.map((event) {
      final json = jsonDecode(event as String) as Map<String, dynamic>;
      return '[${json['type'] ?? level}] ${json['payload'] ?? event}';
    });
  }

  /// 释放底层 HTTP 客户端资源。
  void close() => _http.close();
}
