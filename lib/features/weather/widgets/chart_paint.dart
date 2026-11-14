import 'package:flutter/painting.dart';

/// [source] cut into [dash]-long pieces separated by [gap] (SVG stroke-dasharray).
Path dashedPath(Path source, double dash, double gap) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += dash + gap) {
      out.addPath(metric.extractPath(d, d + dash), Offset.zero);
    }
  }
  return out;
}

/// Horizontal anchor of a text label relative to its x position.
enum TextAnchor { start, middle }

/// Paints [text] with its vertical centre at [at].dy; [halo] adds a bg-coloured
/// outline under the glyphs (SVG `paint-order: stroke`).
void paintLabel(
  Canvas canvas,
  String text,
  Offset at,
  TextStyle style, {
  TextAnchor anchor = TextAnchor.middle,
  Color? halo,
  double haloWidth = 4,
}) {
  TextPainter layout(TextStyle s) => TextPainter(
    text: TextSpan(text: text, style: s),
    textDirection: TextDirection.ltr,
  )..layout();
  final painter = layout(style);
  final dx = anchor == TextAnchor.middle ? at.dx - painter.width / 2 : at.dx;
  final origin = Offset(dx, at.dy - painter.height / 2);
  if (halo != null) {
    layout(
      style.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = haloWidth
          ..strokeJoin = StrokeJoin.round
          ..color = halo,
        color: null,
      ),
    ).paint(canvas, origin);
  }
  painter.paint(canvas, origin);
}
