import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// ---------------------------------------------------------------------------
/// The PURE DART side of the comparison.
///
/// boxBlurDart() below is deliberately written to do exactly the same work as
/// box_blur_rgba() in image_lab.c: same algorithm, same loop order. That makes
/// the benchmark fair: when Dart and C timings differ, it's the language and
/// runtime that differ, not the algorithm.
/// ---------------------------------------------------------------------------

/// Builds a w x h RGBA image: a colour gradient plus pseudo-random noise, so
/// there is something to blur without needing a real photo.
///
/// Deterministic: the same seed gives the same image every time, so timings
/// between runs are comparable.
Uint8List makeTestImage(int w, int h) {
  final out = Uint8List(w * h * 4); /// 4 bytes per pixel: R, G, B, A
  var seed = 12345;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      /// A tiny linear congruential random generator, so we don't depend on
      /// dart:math's Random (this keeps the output identical on every run).
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final noise = (seed >> 16) & 0x3f; /// 0..63

      final i = (y * w + x) * 4; /// index of this pixel's first byte
      out[i] = math.min(255, x * 255 ~/ w + noise); /// red grows left to right
      out[i + 1] = math.min(255, y * 255 ~/ h + noise); /// green grows downward
      out[i + 2] = (x ^ y) & 0xff; /// blue: an XOR pattern, gives sharp detail
      out[i + 3] = 255; /// fully opaque
    }
  }
  return out;
}

/// Box blur written in plain Dart. [r] is the radius: each output pixel becomes
/// the average of the (2r+1) pixels around it.
///
/// It's "separable": blur every row first (horizontal pass into `tmp`), then
/// blur every column of that result (vertical pass into `dst`). That gives the
/// same look as a full 2D box blur but with far less work.
///
/// This is intentionally the simple version (it re-adds the whole window for
/// every pixel). It's slow enough that the speed difference between Dart and
/// C is easy to see.
Uint8List boxBlurDart(Uint8List src, int w, int h, int r) {
  final tmp = Uint8List(src.length); /// result of the horizontal pass
  final dst = Uint8List(src.length); /// final result

  /// Pass 1: horizontal
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      /// Clamp the window to the image edges so we never read outside the row.
      final x0 = x - r < 0 ? 0 : x - r;
      final x1 = x + r >= w ? w - 1 : x + r;
      final count = x1 - x0 + 1; // smaller near the edges

      var sr = 0, sg = 0, sb = 0;
      for (var k = x0; k <= x1; k++) {
        final q = (row + k) * 4;
        sr += src[q];
        sg += src[q + 1];
        sb += src[q + 2];
      }
      final o = (row + x) * 4;
      tmp[o] = sr ~/ count;
      tmp[o + 1] = sg ~/ count;
      tmp[o + 2] = sb ~/ count;
      tmp[o + 3] = 255;
    }
  }

  /// ---- Pass 2: vertical (same idea, but walking down each column) ----
  for (var y = 0; y < h; y++) {
    final y0 = y - r < 0 ? 0 : y - r;
    final y1 = y + r >= h ? h - 1 : y + r;
    final count = y1 - y0 + 1;
    for (var x = 0; x < w; x++) {
      var sr = 0, sg = 0, sb = 0;
      for (var k = y0; k <= y1; k++) {
        final q = (k * w + x) * 4;
        sr += tmp[q];
        sg += tmp[q + 1];
        sb += tmp[q + 2];
      }
      final o = (y * w + x) * 4;
      dst[o] = sr ~/ count;
      dst[o + 1] = sg ~/ count;
      dst[o + 2] = sb ~/ count;
      dst[o + 3] = 255;
    }
  }
  return dst;
}

/// The two functions below run the same work on a background isolate (a separate
/// worker with its own memory), so the UI isolate stays free to draw frames.
///
/// Isolate.run copies what the closure captures into the worker, so [src] is
/// copied once on the way in. The returned list is handed back without a copy.

/// Generates the test image on a worker. [size] is a plain int, so it is the
/// only thing sent to the isolate.
Future<Uint8List> makeTestImageInBackground(int size) =>
    Isolate.run(() => makeTestImage(size, size));

/// Pure-Dart blur on a worker: smooth UI, but the pixels are copied across.
Future<Uint8List> boxBlurInBackground(Uint8List src, int w, int h, int r) =>
    Isolate.run(() => boxBlurDart(src, w, h, r));