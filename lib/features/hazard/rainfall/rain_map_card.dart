import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show OverlayImage;
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/radar/radar_frame_repository.dart' show RadarFrame;
import '../../radar/widgets/radar_map_view.dart';

/// Shared shell of the two 雨量 map cards: header (title + time line), then [children]
/// (map first, then value / control rows), then the legend and the footnote.
class RainMapCard extends StatelessWidget {
  const RainMapCard({super.key, required this.title, required this.meta, required this.children, required this.legend, required this.note});

  final String title;
  final String meta;
  final List<Widget> children;
  final Widget legend;
  final String note;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: title,
      meta: meta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          ...children,
          legend,
          Text(note, style: AppType.caption1.copyWith(color: AppPalette.fg3)),
        ],
      ),
    );
  }
}

/// The map of a [RainMapCard]: one chip style and one aspect / lock rule.
/// [cameraLink] null = stacked: square, locked until unlocked.
class RainMapView extends StatelessWidget {
  const RainMapView({
    super.key,
    required this.cameraLink,
    this.me,
    this.loading = false,
    this.muted = false,
    this.chipIcon,
    this.chipText,
    this.semanticsLabel,
    this.upcoming = const [],
    this.overlayImages = const [],
  });

  final RadarCameraLink? cameraLink;
  final LatLng? me;
  final bool loading;
  final bool muted;
  final IconData? chipIcon;
  final String? chipText;
  final String? semanticsLabel;
  final List<RadarFrame> upcoming;
  final List<OverlayImage> overlayImages;

  @override
  Widget build(BuildContext context) {
    return RadarMapView(
      me: me,
      loading: loading,
      muted: muted,
      chipIcon: chipIcon,
      chipText: chipText,
      semanticsLabel: semanticsLabel,
      upcoming: upcoming,
      overlayImages: overlayImages,
      aspectRatio: cameraLink == null ? 1 : radarMapDefaultAspectRatio,
      startLocked: cameraLink == null,
      cameraLink: cameraLink,
    );
  }
}

/// Legend: a title, one colour bar of equal-width swatches, and labels under it.
/// [marks] = (first colour index of a band, label).
class RainLegend extends StatelessWidget {
  const RainLegend({super.key, required this.title, required this.semanticsLabel, required this.colours, required this.marks});

  final String title;
  final String semanticsLabel;
  final List<Color> colours;
  final List<(int, String)> marks;

  @override
  Widget build(BuildContext context) {
    final caption = AppType.caption2.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular);
    return Semantics(
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s4,
        children: [
          Text(
            title,
            style: AppType.caption1.copyWith(color: AppPalette.fg2, fontWeight: FontWeight.w600),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: AppSize.legendBar,
              child: Row(
                children: [for (final c in colours) Expanded(child: ColoredBox(color: c))],
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < marks.length; i++)
                Expanded(
                  flex: (i + 1 < marks.length ? marks[i + 1].$1 : colours.length) - marks[i].$1,
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    child: Text(marks[i].$2, softWrap: false, style: caption),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
