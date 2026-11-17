import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'status.dart';

/// `.card.card--a` / `.card--hero`, normalised: every card (hero included)
/// uses radius 12, padding 16 / 16 / 20, gap 16, no border. Hero only
/// differs by background and shadow-8.
///
/// Per-card data states (one card fails, the others keep their data):
/// - [AppCard.loading]: header + skeleton of the data height (no layout jump).
/// - [AppCard.error]: replaces the card with an error banner whose text is the
///   Failure message as-is (no default values shown).
/// - [AppCard.empty]: replaces the card with an empty banner.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.title,
    this.meta,
    this.trailing,
    required Widget this.child,
    this.hero = false,
    this.heroColor,
    this.flush = false,
    this.dense = false,
  })  : _state = _CardState.data,
        message = null,
        onRetry = null,
        skeletonHeight = null;

  const AppCard.loading({
    super.key,
    this.title,
    required double this.skeletonHeight,
    this.hero = false,
  })  : _state = _CardState.loading,
        meta = null,
        trailing = null,
        child = null,
        heroColor = null,
        flush = false,
        dense = false,
        message = null,
        onRetry = null;

  /// [title] e.g. 「無法取得雨量資料」; [message] = `Failure.message`.
  const AppCard.error({
    super.key,
    required String this.title,
    required String this.message,
    required VoidCallback this.onRetry,
  })  : _state = _CardState.error,
        meta = null,
        trailing = null,
        child = null,
        hero = false,
        heroColor = null,
        flush = false,
        dense = false,
        skeletonHeight = null;

  const AppCard.empty({
    super.key,
    required String this.title,
    this.message,
  })  : _state = _CardState.empty,
        meta = null,
        trailing = null,
        child = null,
        hero = false,
        heroColor = null,
        flush = false,
        dense = false,
        onRetry = null,
        skeletonHeight = null;

  /// `.card__title` (subtitle1).
  final String? title;

  /// `.card__meta` (caption1, foreground3) under the title, e.g. 「觀測 14:10」.
  final String? meta;

  /// Right side of `.card__header` (badge, small button).
  final Widget? trailing;
  final Widget? child;

  /// `.card--hero`: brand-160 → bg-1 gradient (or [heroColor]) + shadow-8.
  final bool hero;

  /// Solid hero background, e.g. warning level bg on the warnings hero.
  final Color? heroColor;

  /// `.card--flush`: no padding, content clipped (maps, edge-to-edge lists).
  final bool flush;

  /// Compact padding 12 / 16 and gap 8, for a card that is a dense strip of readings.
  final bool dense;

  /// Error / empty banner text ([AppCard.error]: the Failure message).
  final String? message;
  final VoidCallback? onRetry;

  /// [AppCard.loading]: height of the data block the skeleton stands in for.
  final double? skeletonHeight;

  final _CardState _state;

  static const _padding = EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s16, AppSpace.s16, AppSpace.s20);
  static const _densePadding = EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s12);
  static const _heroGradientStop = 0.64;

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _CardState.error => StatusBanner(
          tone: StatusTone.error,
          title: title!,
          text: message,
          actions: [RetryButton(onPressed: onRetry!)],
        ),
      _CardState.empty => StatusBanner(tone: StatusTone.empty, title: title!, text: message),
      _CardState.loading => _frame([
          if (title != null) _header(),
          Skeleton(height: skeletonHeight!),
        ]),
      _CardState.data => _frame([
          if (title != null || trailing != null) _header(),
          child!,
        ]),
    };
  }

  Widget _frame(List<Widget> children) {
    final solid = heroColor;
    final decoration = BoxDecoration(
      color: hero ? solid : AppPalette.background1,
      gradient: hero && solid == null
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppPalette.brand160, AppPalette.background1],
              stops: [0, _heroGradientStop],
            )
          : null,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      boxShadow: hero ? AppShadows.s8 : AppShadows.s4,
    );
    return RepaintBoundary(
      child: Container(
        decoration: decoration,
        clipBehavior: flush ? Clip.antiAlias : Clip.none,
        padding: flush ? EdgeInsets.zero : (dense ? _densePadding : _padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: flush ? AppSpace.s0 : (dense ? AppSpace.s8 : AppSpace.s16),
          children: children,
        ),
      ),
    );
  }

  Widget _header() {
    final heading = title;
    final metaText = meta;
    final end = trailing;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading != null) Text(heading, style: AppType.subtitle1.copyWith(color: AppPalette.foreground1)),
              if (metaText != null) Text(metaText, style: AppType.caption1.copyWith(color: AppPalette.foreground3)),
            ],
          ),
        ),
        if (end != null) ...[const SizedBox(width: AppSpace.s8), end],
      ],
    );
  }
}

enum _CardState { data, loading, error, empty }

/// `.section__header`: section title (subtitle1) with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final end = trailing;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.controlSmall),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppType.subtitle1.copyWith(color: AppPalette.foreground1))),
          ?end,
        ],
      ),
    );
  }
}
