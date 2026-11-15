import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/services/prometheus_exporter.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

class _Server extends Stream<HttpRequest> implements HttpServer {
  _Server(this.address, this.port);
  @override
  final InternetAddress address;
  @override
  final int port;
  bool closed = false;
  @override
  Future<HttpServer> close({bool force = false}) async {
    closed = true;
    return this;
  }

  @override
  StreamSubscription<HttpRequest> listen(
    void Function(HttpRequest)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<HttpRequest>.empty().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  late List<({InternetAddress address, int port, Completer<HttpServer> result})>
  binds;
  late PrometheusExporter exporter;
  setUp(() {
    binds = [];
    exporter = PrometheusExporter(
      BleProvider(),
      bind: (address, port) {
        final result = Completer<HttpServer>();
        binds.add((address: address, port: port, result: result));
        return result.future;
      },
    );
  });
  tearDown(() async {
    await exporter.stop();
  });

  test('pending enable cannot resurrect a disabled endpoint', () async {
    final enable = exporter.configure(
      enabled: true,
      port: 9471,
      allowRemote: true,
    );
    await tick();
    final disable = exporter.configure(
      enabled: false,
      port: 9471,
      allowRemote: true,
    );
    expect(exporter.transitioning, isTrue);
    final stale = _Server(binds.single.address, 9471);
    binds.single.result.complete(stale);
    await Future.wait([enable, disable]);
    expect(stale.closed, isTrue);
    expect(exporter.running, isFalse);
    expect(exporter.transitioning, isFalse);
  });

  for (final fail in [false, true]) {
    test('remote-to-loopback closes the stale wildcard, fail=$fail', () async {
      final first = exporter.configure(
        enabled: true,
        port: 9471,
        allowRemote: true,
      );
      await tick();
      final next = exporter.configure(
        enabled: true,
        port: 9471,
        allowRemote: false,
      );
      final stale = _Server(binds.first.address, 9471);
      binds.first.result.complete(stale);
      await tick();
      expect(stale.closed, isTrue);
      expect(binds.last.address.isLoopback, isTrue);
      final local = _Server(binds.last.address, 9471);
      if (fail) {
        binds.last.result.completeError(const SocketException('bind failed'));
      } else {
        binds.last.result.complete(local);
      }
      await Future.wait([first, next]);
      expect(exporter.running, !fail);
      expect(exporter.allowsRemote, fail ? isNull : isFalse);
      if (fail) expect(exporter.error, contains('bind failed'));
    });
  }

  test('port changes never leave an untracked server', () async {
    final first = exporter.configure(
      enabled: true,
      port: 9471,
      allowRemote: false,
    );
    await tick();
    final next = exporter.configure(
      enabled: true,
      port: 9472,
      allowRemote: false,
    );
    final stale = _Server(binds.first.address, 9471);
    binds.first.result.complete(stale);
    await tick();
    final latest = _Server(binds.last.address, 9472);
    binds.last.result.complete(latest);
    await Future.wait([first, next]);
    expect(stale.closed, isTrue);
    expect(latest.closed, isFalse);
    expect(exporter.url, endsWith(':9472/metrics'));
    await exporter.stop();
    expect(latest.closed, isTrue);
  });

  test(
    'identical requests do not restart pending or running sockets',
    () async {
      final first = exporter.configure(
        enabled: true,
        port: 9471,
        allowRemote: false,
      );
      final same = exporter.configure(
        enabled: true,
        port: 9471,
        allowRemote: false,
      );
      expect(identical(first, same), isTrue);
      await tick();
      final server = _Server(binds.single.address, 9471);
      binds.single.result.complete(server);
      await first;
      await exporter.configure(enabled: true, port: 9471, allowRemote: false);
      expect(binds, hasLength(1));
      expect(server.closed, isFalse);
    },
  );

  for (final dispose in [false, true]) {
    test('stop/dispose invalidates pending binds, dispose=$dispose', () async {
      final first = exporter.configure(
        enabled: true,
        port: 9471,
        allowRemote: true,
      );
      await tick();
      Future<void>? stop;
      if (dispose) {
        exporter.dispose();
      } else {
        stop = exporter.stop();
      }
      final stale = _Server(binds.single.address, 9471);
      binds.single.result.complete(stale);
      await first;
      await stop;
      expect(stale.closed, isTrue);
      expect(exporter.running, isFalse);
      if (dispose) {
        await exporter.configure(enabled: true, port: 9471, allowRemote: true);
        expect(binds, hasLength(1));
      }
    });
  }
}
