# Flutter component map (Team A mockups → Dart)

Source: `docs/design/tokens-fluent2-light.css`, `docs/design/components.css`, `docs/design/team-a/*.html`.
Rules for page screens: import tokens and widgets from `lib/core/`. Do not write colour literals or `Colors.*`. Use `AppPalette.*` only.

## Tokens: `lib/core/theme/app_tokens.dart`

| CSS | Dart |
|---|---|
| `--color-*` (bg, fg, stroke, brand ramp and aliases, status, temp, rain, icon tints, alert-1…4) | `AppPalette.<camelCase>`, e.g. `--color-brand-fg-strong` → `AppPalette.brandFgStrong`, `--color-alert-2-bg` → `AppPalette.alert2Bg` |
| `--dbz-0 … --dbz-60` (data-vis exception) | `AppPalette.dbz0 … dbz60` |
| transparent | `AppPalette.transparent` |
| `--space-N` | `AppSpace.s0 … s40` |
| `--shape-extra-small/small/medium/extra-large/full` | `AppRadius.extraSmall/small/medium/extraLarge/full` |
| `--stroke-thin/thick/thicker` | `AppStroke.thin/thick/thicker` |
| `--size-*`, `--layout-max-width` | `AppSize.touch, control, controlSm, appBar, bottomNav, icon16…icon64, sliderTrack, sliderThumb, legendBar, spinner, dot, layoutMaxWidth` |
| `--shadow-2/4/8` | `AppShadows.s2/s4/s8` (`List<BoxShadow>`) |
| `--duration-*`, `--curve-*` | `AppMotion.fast / normal`, `AppMotion.decelerateMid / easyEase` |
| `.text-caption2 … .text-display` | `AppType.caption2, caption1, body1, body1Strong, body2, subtitle2, subtitle1, display`. These styles have no colour. Add it with `.copyWith(color: AppPalette.fg1)`. |
| `.num` (tabular-nums) | `style.copyWith(fontFeatures: AppType.tabular)` |

Theme: `lib/core/theme/app_theme.dart` → `AppTheme.light`. The app is light-only. Fonts use the platform default with offline CJK fallback (`PingFang TC`, `Microsoft JhengHei`, `Noto Sans CJK TC`). The app does not load fonts from the network.

## Shell: `lib/app_shell.dart`

| Mockup | Dart |
|---|---|
| `.app-shell` (480 column) + `.bottom-nav` | `AppShell()`. It uses a Material `NavigationBar` themed from tokens. The order is 天氣｜雷達｜雨量｜警特報｜地點. A tab is built on first visit, then kept alive in an `IndexedStack`. |
| switch tab from a page (e.g. 「手動選擇」 → 地點) | `ref.read(appTabProvider.notifier).select(AppTab.location)`. `AppTab` is `weather, radar, rainfall, warnings, location` (bottom-nav order); `appTabProvider` holds the selected tab. Both live in `lib/core/navigation/app_tab.dart`. |

Each tab screen returns an `AppPageScaffold`. Do not add a `Scaffold` or `bottomNavigationBar` in a tab screen.

## Widgets: `lib/core/widgets/`

| Mockup class | Dart widget | File | Constructor params |
|---|---|---|---|
| `.app-bar` + `.page` + credit line | `AppPageScaffold` | `page_scaffold.dart` | `header` (AppPageHeader, required), `children` (List<Widget>, required; gap 16, padding 8/16/24), `source` (SourceLine?), `onRefresh` (Future<void> Function()?; pull-to-refresh) |
| `.app-bar` | `AppPageHeader` | `page_scaffold.dart` | `title` (String, required), `subtitle` (String?), `subtitleIcon` (IconData?, e.g. `Icons.schedule` for the clock, `Icons.near_me_outlined` for locate), `subtitleIconColor` (default brandFg; pass `AppPalette.warningFg` for `.app-bar__subtitle--warn`), `actions` (List<Widget>, use AppIconButton), `onTitleTap` (VoidCallback?; home 「切換地點」 title with chevron), `onBack` (VoidCallback?; `.app-bar--has-back`) |
| `.page-foot` / `.page-source` (unified) | `SourceLine` | `page_scaffold.dart` | `datasetIds` (List<String>, required, non-empty) → 「資料來源：中央氣象署 開放資料（A、B）」. Pass it only on frames that show data. Leave it out on loading and error frames. It is pinned at the viewport bottom on short pages and follows the content on long pages. |
| `.card.card--a`, `.card--hero` | `AppCard` | `app_card.dart` | `title` (String?), `meta` (String?), `trailing` (Widget?), `child` (Widget, required), `hero` (bool; brand gradient + shadow-8), `heroColor` (Color?; solid hero bg, e.g. warnings level bg or location intro), `flush` (bool; no padding, clipped) |
| per-card loading (skeleton) | `AppCard.loading` | `app_card.dart` | `title` (String?), `skeletonHeight` (double, required; the data block height, so the layout does not jump), `hero` (bool) |
| per-card error (`.status-banner--error` in place of the card) | `AppCard.error` | `app_card.dart` | `title` (String, required, e.g. 「無法取得雨量資料」), `message` (String, required: `Failure.message` as-is), `onRetry` (VoidCallback, required) |
| per-card empty (`.status-banner--empty`) | `AppCard.empty` | `app_card.dart` | `title` (String, required), `message` (String?) |
| `.section__header` | `SectionHeader` | `app_card.dart` | `title` (String, required; subtitle1), `trailing` (Widget?) |
| `.status-banner--loading/error/empty/permission/alert-1/alert-3` | `StatusBanner` | `status.dart` | `tone` (StatusTone, required), `title` (String, required), `text` (String?), `icon` (IconData?; a default exists per tone), `actions` (List<Widget>) |
| `.empty-state` | `EmptyState` | `status.dart` | `title` (String, required), `text` (String?), `icon` (default `Icons.cloud_off_outlined`), `error` (bool; danger icon), `actions` (List<Widget>) |
| `.spinner` | `AppSpinner` | `status.dart` | none |
| `.skeleton` | `Skeleton` | `status.dart` | `height` (double, required), `width` (double?), `circle` (bool) |
| 「重試」 button | `RetryButton` | `status.dart` | `onPressed` (required), `primary` (bool; true = full-page primary, false = small secondary in a banner) |
| `.btn--primary/secondary/subtle`, `.btn--sm`, `.btn--block` | `AppButton` | `buttons.dart` | `label` (String, required), `onPressed` (VoidCallback?, required; null = disabled), `variant` (AppButtonVariant, default secondary), `icon` (IconData?), `small` (bool), `block` (bool) |
| `.btn--subtle.btn--icon` | `AppIconButton` | `buttons.dart` | `icon` (required), `tooltip` (String, required; the aria-label), `onPressed` (VoidCallback?, required) |
| `.chip` | `AppChip` | `choices.dart` | `label` (required), `selected` (bool, required), `onTap` (required), `icon` (IconData?). Group with `Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8)` (`.chip-group`), or with a horizontal `SingleChildScrollView` + `Row(spacing: AppSpace.s8)` (`.chip-group--scroll`). |
| `.segmented.segmented--block` (Team A view tabs) | `AppSegmented<T>` | `choices.dart` | `segments` (List<(T, String)>, required), `selected` (T, required), `onChanged` (ValueChanged<T>, required) |
| `.badge`, `.badge--rain/brand/alert-1…4` | `AppBadge` | `data_display.dart` | `label` (required), `tone` (BadgeTone, default neutral), `icon` (IconData?) |
| `.metric` | `MetricTile` | `data_display.dart` | `label` (required), `value` (required; one line, ellipsis), `icon` (IconData?), `onHero` (bool; `.hero .metric`) |
| `.metric-grid` | `MetricGrid` | `data_display.dart` | `children` (List<MetricTile>, required; 2 columns, rows equal height) |
| `.list` | `AppList` | `data_display.dart` | `children` (List<AppListRow>, required) |
| `.list-row` | `AppListRow` | `data_display.dart` | `primary` (required), `secondary` (String?), `leading` (Widget?), `trailing` (Widget?; gets tabular body1 fg2), `selected` (bool), `enabled` (bool), `onTap` (VoidCallback?) |

## Review fixes built into the shared widgets

- Hero and normal cards use the same padding (16 / 16 / 20). This removes the 4px hero inset.
- Hero cards have no 1px border.
- The credit line has one widget with one placement, shown only on frames that show data.

## Page-specific parts (not shared; build them in the page file with tokens)

Home: `.hero` internals, 72-hour chart, sun card, `.temp-range`, `.ptr`, `.loc-btn`. Radar: `.map*`, `.fab`, `.playback`, `.slider`, `.legend` (dBZ bar), `.card--outline`, `pb-settings`. Rainfall: `.legend__list` swatches, `.list-head`. Warnings: level hero internals. Location: `.loc-hero`, `.intro`.
Underline tabs (`.tab-list`) are not used by any Team A page. Team A uses `AppSegmented` instead.
