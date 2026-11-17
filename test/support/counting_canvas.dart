// phone-performance: a Canvas that counts what a frame asks the GPU to do.
//
// It records into a real PictureRecorder canvas (so transforms, clips and
// save counts behave exactly as in the game) and counts every call, per
// layer: the scene marks its layers through LayerSink (lib/game/perf), so
// the counts split into background, ground, combat, shots, air, overlay.
// Counts, not wall time: they are deterministic, so they can gate a test.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/perf/frame_budget.dart';

/// One layer's counts in one frame (or summed over frames).
class LayerCost {
  int calls = 0; // every draw call (not save/translate/clip)
  int images = 0; // drawImage, drawImageRect, drawImageNine
  int atlasCalls = 0; // drawAtlas / drawRawAtlas calls
  int atlasSprites = 0; // sprites inside those calls
  int vertexCalls = 0; // drawVertices calls
  int saveLayers = 0;
  int imageFilters = 0; // draw or saveLayer paints carrying an ImageFilter
  int maskFilters = 0; // paints carrying a MaskFilter (blur)
  int shaders = 0; // paints carrying a Shader
  int paths = 0;
  int rects = 0; // drawRect, drawRRect, drawCircle, drawOval, drawLine...
  int pictures = 0;
  int text = 0;

  void add(LayerCost o) {
    calls += o.calls;
    images += o.images;
    atlasCalls += o.atlasCalls;
    atlasSprites += o.atlasSprites;
    vertexCalls += o.vertexCalls;
    saveLayers += o.saveLayers;
    imageFilters += o.imageFilters;
    maskFilters += o.maskFilters;
    shaders += o.shaders;
    paths += o.paths;
    rects += o.rects;
    pictures += o.pictures;
    text += o.text;
  }

  Map<String, int> toMap() => {
    'calls': calls,
    'images': images,
    'atlasCalls': atlasCalls,
    'atlasSprites': atlasSprites,
    'vertexCalls': vertexCalls,
    'saveLayers': saveLayers,
    'imageFilters': imageFilters,
    'maskFilters': maskFilters,
    'shaders': shaders,
    'paths': paths,
    'rects': rects,
    'pictures': pictures,
    'text': text,
  };

  @override
  String toString() =>
      'calls=$calls images=$images atlas=$atlasCalls/$atlasSprites '
      'vertices=$vertexCalls saveLayers=$saveLayers blurs=${imageFilters + maskFilters} '
      'shaders=$shaders paths=$paths rects=$rects';
}

class CountingCanvas implements ui.Canvas, LayerSink {
  CountingCanvas(ui.PictureRecorder recorder) : _c = ui.Canvas(recorder);
  final ui.Canvas _c;

  /// Counts per layer name, in first-seen order. Calls before the first
  /// marker count as 'frame'.
  final Map<String, LayerCost> layers = {};
  String _layer = 'frame';
  LayerCost get _now => layers.putIfAbsent(_layer, LayerCost.new);

  LayerCost get total {
    final t = LayerCost();
    for (final l in layers.values) {
      t.add(l);
    }
    return t;
  }

  @override
  void layer(String name) => _layer = name;

  void _paint(ui.Paint p) {
    final n = _now;
    n.calls++;
    if (p.imageFilter != null) n.imageFilters++;
    if (p.maskFilter != null) n.maskFilters++;
    if (p.shader != null) n.shaders++;
  }

  void _rect(ui.Paint p) {
    _paint(p);
    _now.rects++;
  }

  // State: delegated, not counted as draws.
  @override
  void save() => _c.save();
  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    final n = _now;
    n.saveLayers++;
    if (paint.imageFilter != null) n.imageFilters++;
    if (paint.maskFilter != null) n.maskFilters++;
    _c.saveLayer(bounds, paint);
  }

  @override
  void restore() => _c.restore();
  @override
  void restoreToCount(int count) => _c.restoreToCount(count);
  @override
  int getSaveCount() => _c.getSaveCount();
  @override
  void translate(double dx, double dy) => _c.translate(dx, dy);
  @override
  void scale(double sx, [double? sy]) => _c.scale(sx, sy);
  @override
  void rotate(double radians) => _c.rotate(radians);
  @override
  void skew(double sx, double sy) => _c.skew(sx, sy);
  @override
  void transform(Float64List matrix4) => _c.transform(matrix4);
  @override
  Float64List getTransform() => _c.getTransform();
  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => _c.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) =>
      _c.clipRRect(rrect, doAntiAlias: doAntiAlias);
  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) =>
      _c.clipPath(path, doAntiAlias: doAntiAlias);
  @override
  ui.Rect getLocalClipBounds() => _c.getLocalClipBounds();
  @override
  ui.Rect getDestinationClipBounds() => _c.getDestinationClipBounds();

  // Draws: counted, then delegated.
  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    final n = _now;
    n.calls++;
    n.rects++;
    _c.drawColor(color, blendMode);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _rect(paint);
    _c.drawLine(p1, p2, paint);
  }

  @override
  void drawPaint(ui.Paint paint) {
    _rect(paint);
    _c.drawPaint(paint);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _rect(paint);
    _c.drawRect(rect, paint);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    _rect(paint);
    _c.drawRRect(rrect, paint);
  }

  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) {
    _rect(paint);
    _c.drawDRRect(outer, inner, paint);
  }

  @override
  void drawOval(ui.Rect rect, ui.Paint paint) {
    _rect(paint);
    _c.drawOval(rect, paint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _rect(paint);
    _c.drawCircle(c, radius, paint);
  }

  @override
  void drawArc(
    ui.Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    ui.Paint paint,
  ) {
    _rect(paint);
    _c.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    _paint(paint);
    _now.paths++;
    _c.drawPath(path, paint);
  }

  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) {
    _paint(paint);
    _now.images++;
    _c.drawImage(image, offset, paint);
  }

  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    _paint(paint);
    _now.images++;
    _c.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawImageNine(
    ui.Image image,
    ui.Rect center,
    ui.Rect dst,
    ui.Paint paint,
  ) {
    _paint(paint);
    _now.images++;
    _c.drawImageNine(image, center, dst, paint);
  }

  @override
  void drawPicture(ui.Picture picture) {
    final n = _now;
    n.calls++;
    n.pictures++;
    _c.drawPicture(picture);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    final n = _now;
    n.calls++;
    n.text++;
    _c.drawParagraph(paragraph, offset);
  }

  @override
  void drawPoints(ui.PointMode pointMode, List<ui.Offset> points, ui.Paint p) {
    _rect(p);
    _c.drawPoints(pointMode, points, p);
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, ui.Paint p) {
    _rect(p);
    _c.drawRawPoints(pointMode, points, p);
  }

  @override
  void drawVertices(ui.Vertices vertices, ui.BlendMode blendMode, ui.Paint p) {
    _paint(p);
    _now.vertexCalls++;
    _c.drawVertices(vertices, blendMode, p);
  }

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<ui.Rect> rects,
    List<ui.Color>? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _paint(paint);
    final n = _now;
    n.atlasCalls++;
    n.atlasSprites += rects.length;
    _c.drawAtlas(atlas, transforms, rects, colors, blendMode, cullRect, paint);
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _paint(paint);
    final n = _now;
    n.atlasCalls++;
    n.atlasSprites += rects.length ~/ 4;
    _c.drawRawAtlas(
      atlas,
      rstTransforms,
      rects,
      colors,
      blendMode,
      cullRect,
      paint,
    );
  }

  @override
  void drawShadow(
    ui.Path path,
    ui.Color color,
    double elevation,
    bool transparentOccluder,
  ) {
    final n = _now;
    n.calls++;
    n.paths++;
    _c.drawShadow(path, color, elevation, transparentOccluder);
  }

  // Newer Canvas members (rounded superellipses and the like) land here:
  // counted as one call each and not drawn.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    _now.calls++;
    return null;
  }
}
