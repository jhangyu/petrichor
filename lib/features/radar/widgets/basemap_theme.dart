import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

/// The basemap theme without sprite patterns, and what was changed.
typedef PatternFreeTheme = ({vt.Theme theme, int recoloured, List<String> dropped});

/// Matches the variant suffix of a layer id, so `land-forest-pattern`,
/// `land-forest-fill` and `land-cemetery-fill-9-13` reduce to their land
/// kind (`land-forest`, `land-cemetery`).
final _layerVariant = RegExp(r'-(fill|pattern)(-.*)?$');

/// Removes every sprite pattern from [theme]. The plugin draws a pattern
/// with a fresh `ImageShader` per path over a GPU image made by
/// `toImageSync` (flutter_map_vector_tiles 2.11.0 tile_rasterizer.dart:
/// 1607-1628, pattern_resolver.dart:36); on macOS that path crashed the app
/// three times while zooming in (SIGSEGV/SIGTRAP in Skia's GrResourceCache,
/// an SkImage released on the UI thread while the raster thread uploaded a
/// texture). Patterned layers only appear from zoom 9-13, hence "crashes on
/// zoom in".
///
/// A `fill-pattern` layer takes the colour of the plain fill layer of the
/// same land kind (for example `land-forest-fill` for `land-forest-pattern`);
/// one without such a layer is dropped, so the ground under it shows. Line
/// and background layers with a pattern are dropped (Shortbread: the four
/// aerialway lines, none for background).
PatternFreeTheme withoutPatterns(vt.Theme theme) {
  String kind(String id) => id.replaceFirst(_layerVariant, '');
  final plainFills = <String, vt.FillThemeLayer>{};
  for (final layer in theme.layers) {
    if (layer is vt.FillThemeLayer && layer.pattern == null) plainFills.putIfAbsent(kind(layer.id), () => layer);
  }
  var recoloured = 0;
  final dropped = <String>[];
  final layers = <vt.ThemeLayer>[];
  for (final layer in theme.layers) {
    switch (layer) {
      case vt.FillThemeLayer(pattern: _?):
        final plain = plainFills[kind(layer.id)];
        if (plain == null) {
          dropped.add(layer.id);
          continue;
        }
        recoloured++;
        final own = layer.referencedProperties;
        final borrowed = plain.referencedProperties;
        layers.add(
          vt.FillThemeLayer(
              id: layer.id,
              source: layer.source,
              sourceLayer: layer.sourceLayer,
              minzoom: layer.minzoom,
              maxzoom: layer.maxzoom,
              filter: layer.filter,
              color: plain.color,
              opacity: layer.opacity,
              outlineColor: layer.outlineColor,
              antialias: layer.antialias,
              extrusion: layer.extrusion,
              translate: layer.translate,
              sortKey: layer.sortKey,
            )
            // Null means "keep every property", so a null on either side stays null.
            ..referencedProperties = own == null || borrowed == null ? null : {...own, ...borrowed},
        );
      case vt.LineThemeLayer(pattern: _?) || vt.BackgroundThemeLayer(pattern: _?):
        dropped.add(layer.id);
      default:
        layers.add(layer);
    }
  }
  return (theme: vt.Theme(id: '${theme.id}|no-patterns', layers: layers), recoloured: recoloured, dropped: dropped);
}
