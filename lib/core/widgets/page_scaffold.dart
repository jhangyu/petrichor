import 'package:flutter/material.dart';

import '../layout/adaptive.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// `.app-bar` + `.page` + bottom `資料來源` line. One per tab screen.
///
/// [children] are laid out in an [AppGrid] that fills the window width (gap
/// 16, page margin from [WindowSizeClass.pageMargin]); wrap a child in
/// [AppGridItem] / [AppGridItem.full] to span columns. [AppPageScaffold.fill]
/// instead gives one [body] the bounded rest of the viewport without page
/// scroll (panes that scroll themselves). Pass [source] only on frames that
/// show CWA data (loading / error frames have none); it is pinned at the
/// bottom of the viewport on short pages and follows the content on long ones
/// (always pinned with [AppPageScaffold.fill]).
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.header,
    required List<Widget> this.children,
    this.source,
    this.onRefresh,
  }) : body = null;

  /// Non-scrolling page: [body] gets tight width and bounded height.
  const AppPageScaffold.fill({
    super.key,
    required this.header,
    required Widget this.body,
    this.source,
  })  : children = null,
        onRefresh = null;

  final AppPageHeader header;
  final List<Widget>? children;
  final Widget? body;
  final SourceLine? source;

  /// Enables pull-to-refresh when set.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;
    final foot = EdgeInsets.fromLTRB(margin, AppSpace.s16, margin, AppSpace.s24);
    final fillBody = body;
    if (fillBody != null) {
      return ColoredBox(
        color: AppPalette.background3,
        child: Column(
          children: [
            header,
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s0),
                child: fillBody,
              ),
            ),
            if (source case final line?) Padding(padding: foot, child: line),
          ],
        ),
      );
    }
    // ponytail: the grid is built eagerly (pages hold < 20 cards); go lazy if a page grows long lists.
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s0),
          sliver: SliverToBoxAdapter(child: AppGrid(children: children!)),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: foot,
            child: Align(alignment: Alignment.bottomCenter, child: source),
          ),
        ),
      ],
    );
    final refresh = onRefresh;
    return ColoredBox(
      color: AppPalette.background3,
      child: Column(
        children: [
          header,
          Expanded(
            child: refresh == null
                ? scroll
                : RefreshIndicator(
                    onRefresh: refresh,
                    color: AppPalette.brandBackground,
                    backgroundColor: AppPalette.background1,
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
    this.subtitleIconColor = AppPalette.brandForeground,
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
      style: AppType.subtitle1.copyWith(color: AppPalette.foreground1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (titleTap != null) {
      titleWidget = InkWell(
        onTap: titleTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: titleWidget),
            const SizedBox(width: AppSpace.s4),
            const Icon(Icons.expand_more, size: AppSize.icon20, color: AppPalette.foreground3),
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
        color: AppPalette.background1,
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
                            color: AppPalette.foreground3,
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
      style: AppType.caption1.copyWith(color: AppPalette.foreground3),
    );
  }
}
