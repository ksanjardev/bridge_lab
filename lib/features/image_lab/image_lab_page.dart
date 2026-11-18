import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../share_inbox/share_inbox.dart';
import '../share_inbox/shared_item.dart';
import 'dart_image_ops.dart';
import 'native_image_lab.dart';
import 'pixel_image.dart';

/// The filters offered on screen. IMPORTANT: the order must match the ids that
/// filter_rgba() in image_lab.c switches on, because we send `filter.index`
/// straight across the FFI boundary. Reorder this enum and the C side breaks
/// silently.
/// The index of each value must match the filter ids in image_lab.c.
enum PhotoFilter {
  blur('Blur', 'Blur strength'),
  pixelate('Pixelate', 'Block size'),
  grayscale('Grayscale', null),
  sepia('Sepia', null);

  const PhotoFilter(this.label, this.strengthLabel);
  final String label;
  final String? strengthLabel; // null: this filter has no setting
}

class ImageLabPage extends StatefulWidget {
  const ImageLabPage({super.key});

  @override
  State<ImageLabPage> createState() => _ImageLabPageState();
}

class _ImageLabPageState extends State<ImageLabPage> {
  /// The loaded C library. Null if loading failed (shown to the user as a snackbar
  /// instead of crashing the page).
  NativeImageLab? _native;
  String? _nativeError;

  /// The photo as raw RGBA bytes: what we hand to C.
  PixelImage? _source;
  /// The same photo as ui.Image objects: what Flutter can paint. Raw bytes can't
  /// be drawn directly, so we convert each result back (see toUiImage).
  ui.Image? _originalImage;
  ui.Image? _editedImage;

  PhotoFilter _filter = PhotoFilter.pixelate;
  double _strength = 12;
  bool _showOriginal = false;
  bool _busy = false;
  String? _info;
  final _timings = <String, int>{};

  @override
  void initState() {
    super.initState();
    try {
      _native = NativeImageLab();
    } catch (e) {
      _nativeError = '$e';
    }
  }

  @override
  void dispose() {
    _originalImage?.dispose();
    _editedImage?.dispose();
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  SharedItem? get _lastShared => ShareInbox.instance.items
      .where((i) => i.kind == SharedKind.image)
      .firstOrNull;

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _load(() => PixelImage.decodeFile(file.path));
  }

  Future<void> _useShared() async {
    final shared = _lastShared;
    if (shared == null) return;
    await _load(() => PixelImage.decodeFile(shared.path!));
  }

  Future<void> _useSample() async {
    await _load(() async {
      final pixels = await makeTestImageInBackground(768);
      return PixelImage(pixels, 768, 768);
    });
  }

  Future<void> _load(Future<PixelImage> Function() loader) async {
    setState(() => _busy = true);
    try {
      final image = await loader();
      final original = await image.toUiImage();
      if (!mounted) {
        original.dispose();
        return;
      }
      setState(() {
        _source = image;
        _originalImage?.dispose();
        _originalImage = original;
        _editedImage?.dispose();
        _editedImage = null;
      });
      await _apply(); // show an effect straight away
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs the selected filter in native C code, off the UI isolate, and shows the
  /// result. Flow: Dart bytes -> native memory -> C filter in a worker isolate
  /// -> Dart bytes -> ui.Image -> screen.
  Future<void> _apply() async {
    final src = _source;
    if (src == null) return;
    if (_native == null) {
      _snack('Native library not loaded: $_nativeError');
      return;
    }
    setState(() => _busy = true);
    try {
      final watch = Stopwatch()..start();
      final out = await NativeImageLab.filterInBackground(
        src.rgba, src.width, src.height, _filter.index, _strength.round(),
      );
      watch.stop();
      final edited = await PixelImage(out, src.width, src.height).toUiImage();
      if (!mounted) {
        edited.dispose();
        return;
      }
      setState(() {
        _editedImage?.dispose();
        _editedImage = edited;
        _info = '${_filter.label} done by native C code in ${watch.elapsedMilliseconds} ms';
      });
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Developer tool: times one blur "engine" so the four approaches can be
  /// compared. The short delay lets the spinner paint first; without it, a
  /// main-thread engine would block the UI before the spinner ever appeared.
  Future<void> _benchmark(
      String label,
      Future<Uint8List> Function(PixelImage s, int r) op,
      ) async {
    final src = _source;
    if (src == null) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      final watch = Stopwatch()..start();
      await op(src, _strength.round().clamp(1, 30));
      watch.stop();
      if (mounted) setState(() => _timings[label] = watch.elapsedMilliseconds);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The comparison sheet. The spinner is a heartbeat: if it freezes while a row
  /// runs, that engine is blocking the UI isolate. That's the visible proof of
  /// FFI rule #2 (calls are synchronous).
  void _openDeveloperSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> run(String key, Future<Uint8List> Function(PixelImage, int) op) async {
            final f = _benchmark(key, op);
            setSheetState(() {}); // _busy is already true here
            await f;
            if (context.mounted) setSheetState(() {});
          }

          Widget engine(String key, String title, String explanation,
              Future<Uint8List> Function(PixelImage, int) op, {bool needsNative = false}) {
            final ms = _timings[key];
            return ListTile(
              title: Text(title),
              subtitle: Text(explanation),
              trailing: ms != null
                  ? Text('$ms ms', style: const TextStyle(fontWeight: FontWeight.bold))
                  : const Icon(Icons.play_arrow),
              enabled: !_busy && (!needsNative || _native != null),
              onTap: () => run(key, op),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Runs the Blur filter on your photo in four different ways and '
                          'times each one. Tap a row to run it. The spinner below is a '
                          'heartbeat: if it freezes, that row blocked the screen.',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  engine(
                    'dart-main',
                    'Dart on the main thread',
                    'Plain Dart code on the thread that draws the screen. Freezes the app while it works.',
                        (s, r) async => boxBlurDart(s.rgba, s.width, s.height, r),
                  ),
                  engine(
                    'dart-bg',
                    'Dart in a background worker',
                    'The same Dart code in a separate worker (an isolate). The screen stays smooth, but the photo has to be copied there and back.',
                        (s, r) => boxBlurInBackground(s.rgba, s.width, s.height, r),
                  ),
                  engine(
                    'c-main',
                    'Native C on the main thread',
                    'Calls the C library directly through dart:ffi. Fast, but still freezes the screen.',
                        (s, r) async => _native!.blur(s.rgba, s.width, s.height, r),
                    needsNative: true,
                  ),
                  engine(
                    'c-bg',
                    'Native C in a background worker',
                    'C code in a worker. This is what the filters on the main screen use.',
                        (s, r) => NativeImageLab.blurInBackground(s.rgba, s.width, s.height, r),
                    needsNative: true,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Filters'),
        actions: [
          if (_source != null)
            IconButton(
              icon: const Icon(Icons.speed),
              tooltip: 'Developer: compare engines',
              onPressed: _openDeveloperSheet,
            ),
        ],
      ),
      body: _source == null ? _buildEmpty(context) : _buildEditor(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy
            ? const CircularProgressIndicator()
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Edit a photo with native code', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Pick a photo and apply filters. Every filter is a C function '
                  'called from Dart (dart:ffi), running off the main thread.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Pick a photo'),
            ),
            if (_lastShared != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _useShared,
                child: const Text('Use last shared photo'),
              ),
            ],
            TextButton(
              onPressed: _useSample,
              child: const Text('No photo? Try a sample image'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final shown = _showOriginal ? _originalImage : (_editedImage ?? _originalImage);
    final strengthLabel = _filter.strengthLabel;
    final theme = Theme.of(context);

    return Column(
      children: [
        // The photo takes all the space the controls don't need.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _showOriginal = true),
              onTapUp: (_) => setState(() => _showOriginal = false),
              onTapCancel: () => setState(() => _showOriginal = false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RawImage(image: shown, fit: BoxFit.contain),
                    if (_showOriginal)
                      const Positioned(top: 8, left: 8, child: Chip(label: Text('Original'))),
                    if (_busy)
                      const ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text('Hold the photo to see the original', style: theme.textTheme.bodySmall),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in PhotoFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            onSelected: _busy
                                ? null
                                : (_) {
                              setState(() => _filter = f);
                              _apply();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(strengthLabel ?? 'No settings',
                          style: theme.textTheme.bodyMedium),
                    ),
                    Expanded(
                      child: Slider(
                        value: _strength,
                        min: 2,
                        max: 30,
                        divisions: 28,
                        label: '${_strength.round()}',
                        onChanged: (_busy || strengthLabel == null)
                            ? null
                            : (v) => setState(() => _strength = v),
                        onChangeEnd: (_) => _apply(), // apply when the user lets go
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(_info ?? '', style: theme.textTheme.bodySmall),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _pickFromGallery,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Another photo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}