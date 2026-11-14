import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'buttons.dart';

/// `.app-bar` + `.page` + bottom `資料來源` line. One per tab screen.
///
/// [children] are laid out with the page gap (16) and gutter (16). Pass
/// [source] only on frames that show CWA data (loading / error frames have
/// none); it is pinned at the bottom of the viewport on short pages and
/// follows the content on long ones.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.header,
    required this.children,
    this.source,
    this.onRefresh,
  });

  final AppPageHeader header;
  final List<Widget> children;
  final SourceLine? source;

  /// Enables pull-to-refresh when set.
  final Future<void> Function()? onRefresh;

  static const _pagePadding =
      EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s8, AppSpace.gutter, AppSpace.s0);
  static const _footPadding =
      EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s16, AppSpace.gutter, AppSpace.s24);

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: _pagePadding,
          sliver: SliverList.separated(
            itemCount: children.length,
            itemBuilder: (_, i) => children[i],
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s16),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: _footPadding,
            child: Align(alignment: Alignment.bottomCenter, child: source),
          ),
        ),
      ],
    );
    final refresh = onRefresh;
    return ColoredBox(
      color: AppPalette.bg3,
      child: Column(
        children: [
          header,
          Expanded(
            child: refresh == null
                ? scroll
                : RefreshIndicator(
                    onRefresh: refresh,
                    color: AppPalette.brandBg,
                    backgroundColor: AppPalette.bg1,
                    child: scroll,
                  ),
          ),
        ],
      ),
    );
  }
}

/// `.app-bar`: title (subtitle1), optional subtitle line with icon, trailing
/// icon actions. [onTitleTap] turns the title into the home 「切換地點」 button
/// (adds a chevron). [onBack] adds a leading back button (`.app-bar--has-back`).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.subtitleIconColor = AppPalette.brandFg,
    this.actions = const [],
    this.onTitleTap,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final Color subtitleIconColor;
  final List<Widget> actions;
  final VoidCallback? onTitleTap;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    final titleTap = onTitleTap;
    final subtitleText = subtitle;
    final subtitleGlyph = subtitleIcon;

    Widget titleWidget = Text(
      title,
      style: AppType.subtitle1.copyWith(color: AppPalette.fg1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (titleTap != null) {
      titleWidget = InkWell(
        onTap: titleTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: titleWidget),
            const SizedBox(width: AppSpace.s4),
            const Icon(Icons.expand_more, size: AppSize.icon20, color: AppPalette.fg3),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.appBar),
      padding: EdgeInsets.fromLTRB(
        back == null ? AppSpace.s16 : AppSpace.s4,
        MediaQuery.paddingOf(context).top,
        AppSpace.s4,
        AppSpace.s0,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.bg1,
        border: Border(bottom: BorderSide(color: AppPalette.stroke2, width: AppStroke.thin)),
      ),
      child: Row(
        children: [
          if (back != null) AppIconButton(icon: Icons.arrow_back, tooltip: '返回', onPressed: back),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                if (subtitleText != null)
                  Row(
                    children: [
                      if (subtitleGlyph != null) ...[
                        Icon(subtitleGlyph, size: AppSize.icon16, color: subtitleIconColor),
                        const SizedBox(width: AppSpace.s4),
                      ],
                      Expanded(
                        child: Text(
                          subtitleText,
                          style: AppType.caption1.copyWith(
                            color: AppPalette.fg3,
                            fontFeatures: AppType.tabular,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Single page-bottom credit line (`.page-foot` / `.page-source`, unified):
/// 「資料來源：中央氣象署 開放資料（ID、ID）」.
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.datasetIds});

  /// CWA dataset ids shown on this page (at least one), e.g. `['O-A0003-001']`.
  final List<String> datasetIds;

  @override
  Widget build(BuildContext context) {
    return Text(
      '資料來源：中央氣象署 開放資料（${datasetIds.join('、')}）',
      textAlign: TextAlign.center,
      style: AppType.caption1.copyWith(color: AppPalette.fg3),
    );
  }
}
