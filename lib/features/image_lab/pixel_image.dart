import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A picture as RAW PIXELS: width x height pixels, 4 bytes each (red, green,
/// blue, alpha), row after row, with no file format around it.
///
/// This is the format native code wants. C can't read a JPEG or PNG without a
/// decoder, but it can happily loop over plain RGBA bytes. Flutter's
/// ui.Image is the opposite: it's what Flutter can DRAW, but it hides its
/// bytes. This class is the bridge between the two worlds.
class PixelImage {
  PixelImage(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;

  /// Raw pixels -> a ui.Image that Flutter can paint (for RawImage).
  ///
  /// decodeImageFromPixels reports its result through a callback, so we wrap
  /// it in a Completer to be able to `await` it.
  /// The caller owns the returned image and must dispose() it.
  Future<ui.Image> toUiImage() {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, width, height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// Reads an image file (JPEG, PNG...) and turns it into raw RGBA pixels.
  ///
  /// [width] caps the size: photos from a phone camera are 12+ megapixels, and
  /// every filter pass would touch every pixel. Decoding to 1024 px wide keeps
  /// the demo quick; the codec resizes while decoding, which is cheaper than
  /// decoding at full size and shrinking afterwards.
  static Future<PixelImage> decodeFile(String path, {int width = 1024}) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    /// Ask the engine for the decoded pixels as plain RGBA bytes.
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result =
    PixelImage(data!.buffer.asUint8List(), image.width, image.height);

    /// ui.Image and the codec hold native memory the GC doesn't track, so we
    /// release them ourselves. `result` has its own copy of the bytes.
    image.dispose();
    codec.dispose();
    return result;
  }
}