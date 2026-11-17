import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_map/flutter_map.dart' show OverlayImage;
import 'package:latlong2/latlong.dart';

import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/radar/radar_frame_repository.dart' show RadarFrame;
import '../../radar/widgets/radar_map_view.dart';

/// Opacity of the rain overlay on both 雨量 maps.
const rainMapOverlayOpacity = 0.8;

/// Map height chrome in the wide layout: page header and top margin, card padding,
/// card header, legend (title, bar, labels), note and the three gaps. The map takes
/// the rest of the window, as radar's `_heroChromeHeight`. Banners are not counted.
const _wideMapChromeHeight =
    AppSize.appBar +
    AppSpace.s8 +
    AppSpace.s16 +
    AppSpace.s20 +
    AppSize.touch +
    AppSize.icon16 +
    AppSpace.s4 +
    AppSize.legendBar +
    AppSpace.s4 +
    AppSize.icon16 +
    AppSize.icon16 +
    3 * AppSpace.s16;

/// Shared shell of the two 雨量 map cards. Narrow: one card, header, [leading], [banner],
/// [map], [controls], legend, note. Wide (radar's map+controls split): map card on the
/// left (header, [banner], [map] at window height, legend, note), and on the right a
/// column of [stationCard] over a plain card titled [controlsTitle] holding [leading]
/// and [controls] (that card is left out when both are empty). The right card does not scroll, so the wheel there scrolls the page.
/// Wide with no [stationCard], [leading] and [controls]: the map card alone (its row partner is the caller's).
class RainMapCard extends StatelessWidget {
  const RainMapCard({
    super.key,
    required this.wide,
    required this.title,
    required this.meta,
    required this.map,
    required this.legend,
    this.note,
    this.controlsTitle,
    this.banner,
    this.stationCard,
    this.leading = const [],
    this.controls = const [],
  });

  final bool wide;
  final String title;
  final String meta;
  final RainMapView map;
  final Widget legend;
  final String? note;

  /// Title of the controls card; set whenever [leading] or [controls] are not empty.
  final String? controlsTitle;
  final Widget? banner;

  /// Nearest-station card, above the controls card in the wide side pane (narrow: not used).
  final Widget? stationCard;

  /// Controls placed before the map when narrow (e.g. window chips).
  final List<Widget> leading;

  /// Controls placed after the map when narrow (e.g. playback, 此處 row).
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final noteText = note == null ? null : Text(note, style: AppType.caption1.copyWith(color: AppPalette.foreground3));
    if (!wide) {
      return AppCard(
        title: title,
        meta: meta,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s16,
          children: [...leading, ?banner, map, ...controls, legend, ?noteText],
        ),
      );
    }
    final availableHeight = MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top;
    final side = [...leading, ...controls];
    final mapCard = AppCard(
      title: title,
      meta: meta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          ?banner,
          SizedBox(height: math.max(AppLayout.paneMinimumWidth, availableHeight - _wideMapChromeHeight), child: map),
          legend,
          ?noteText,
        ],
      ),
    );
    if (side.isEmpty && stationCard == null) return mapCard;
    return AppTwoPane(
      matchHeight: true,
      mainPane: mapCard,
      sidePane: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppLayout.gridGap,
        children: [
          ?stationCard,
          if (side.isNotEmpty)
            AppCard(
              title: controlsTitle,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s16, children: side),
            ),
        ],
      ),
    );
  }
}

/// The map of a [RainMapCard]: one chip style and one aspect / lock rule.
/// [wide] false = square, locked until unlocked; true = free, sized by the card.
/// [cameraLink] only links the cameras of the maps.
class RainMapView extends StatelessWidget {
  const RainMapView({
    super.key,
    required this.wide,
    required this.cameraLink,
    this.currentPlacePoint,
    this.loading = false,
    this.muted = false,
    this.chipIcon,
    this.chipIconColor = AppPalette.foreground1,
    this.chipText,
    this.semanticsLabel,
    this.upcoming = const [],
    this.overlayImages = const [],
  });

  final bool wide;
  final RadarCameraLink? cameraLink;
  final LatLng? currentPlacePoint;
  final bool loading;
  final bool muted;
  final IconData? chipIcon;
  final Color chipIconColor;
  final String? chipText;
  final String? semanticsLabel;
  final List<RadarFrame> upcoming;
  final List<OverlayImage> overlayImages;

  @override
  Widget build(BuildContext context) {
    return RadarMapView(
      currentPlacePoint: currentPlacePoint,
      loading: loading,
      muted: muted,
      chipIcon: chipIcon,
      chipIconColor: chipIconColor,
      chipText: chipText,
      semanticsLabel: semanticsLabel,
      upcoming: upcoming,
      overlayImages: overlayImages,
      aspectRatio: wide ? radarMapDefaultAspectRatio : 1,
      startLocked: !wide,
      cameraLink: cameraLink,
    );
  }
}

/// Legend: a title, one colour bar of equal-width swatches, and labels under it
/// ([compact]: the title on the bar's left, one line of height).
/// [marks] = (first colour index of a band, label).
class RainLegend extends StatelessWidget {
  const RainLegend({super.key, required this.title, required this.semanticsLabel, required this.colours, required this.marks, this.compact = false});

  final String title;
  final bool compact;
  final String semanticsLabel;
  final List<Color> colours;
  final List<(int, String)> marks;

  @override
  Widget build(BuildContext context) {
    final caption = AppType.caption2.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: AppSize.legendBar,
        child: Row(
          children: [for (final c in colours) Expanded(child: ColoredBox(color: c))],
        ),
      ),
    );
    final labels = Row(
      children: [
        for (var i = 0; i < marks.length; i++)
          Expanded(
            flex: (i + 1 < marks.length ? marks[i + 1].$1 : colours.length) - marks[i].$1,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              child: Text(marks[i].$2, softWrap: false, style: caption),
            ),
          ),
      ],
    );
    final scale = Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpace.s4, children: [bar, labels]);
    return Semantics(
      label: semanticsLabel,
      child: compact
          ? Row(
              spacing: AppSpace.s8,
              children: [
                Text(title, softWrap: false, style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
                Expanded(child: scale),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.s4,
              children: [
                Text(
                  title,
                  style: AppType.caption1.copyWith(color: AppPalette.foreground2, fontWeight: FontWeight.w600),
                ),
                scale,
              ],
            ),
    );
  }
}
