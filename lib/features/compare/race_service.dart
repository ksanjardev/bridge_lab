import 'package:flutter/services.dart';

import '../device_inspector/android_sdk.g.dart';
import '../image_lab/native_image_lab.dart';

/// One contestant's result: average cost of a single call, in microseconds.
class RaceResult {
  RaceResult(this.label, this.microsPerCall, this.note);
  final String label;
  final double? microsPerCall; // null = this contestant couldn't run
  final String note;
}

/// Calls the cheapest possible operation through each approach many times and
/// reports the average cost per call.
class RaceService {
  static const _method = MethodChannel('bridge_lab/bench');
  static const _message =
  BasicMessageChannel<Object?>('bridge_lab/bench_msg', StandardMessageCodec());

  static const calls = 2000;
  static const _warmup = 100;

  /// Channels are ASYNC: every call is awaited, because the reply has to travel
  /// to the platform thread and back as an encoded message.
  Future<double> _timeAsync(Future<void> Function(int i) call) async {
    for (var i = 0; i < _warmup; i++) {
      await call(i); // warm-up so first-call setup doesn't skew the result
    }
    final watch = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await call(i);
    }
    watch.stop();
    return watch.elapsedMicroseconds / calls;
  }

  /// FFI and JNI are SYNC: a plain function call that returns immediately.
  double _timeSync(void Function() call) {
    for (var i = 0; i < _warmup; i++) {
      call();
    }
    final watch = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      call();
    }
    watch.stop();
    return watch.elapsedMicroseconds / calls;
  }

  Future<List<RaceResult>> run() async {
    final results = <RaceResult>[];

    results.add(RaceResult(
      'MethodChannel',
      await _timeAsync((i) async {
        await _method.invokeMethod<int>('ping', i);
      }),
      'async, encoded message, platform thread',
    ));

    results.add(RaceResult(
      'BasicMessageChannel',
      await _timeAsync((i) async {
        await _message.send(i);
      }),
      'async, same transport without method names',
    ));

    try {
      final native = NativeImageLab();
      results.add(RaceResult(
        'dart:ffi',
        _timeSync(() => native.version()),
        'sync direct call into C (includes reading the C string)',
      ));
    } catch (e) {
      results.add(RaceResult('dart:ffi', null, 'library not loaded: $e'));
    }

    try {
      results.add(RaceResult(
        'JNI',
        _timeSync(() => Build$VERSION.SDK_INT),
        'sync direct call into Java (a static field read)',
      ));
    } catch (e) {
      results.add(RaceResult('JNI', null, 'failed: $e'));
    }

    return results;
  }
}