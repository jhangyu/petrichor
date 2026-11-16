import 'package:flutter/material.dart';

import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_loop.dart';
import '../playback_frames.dart';
import '../radar_playback.dart';
import 'radar_legend.dart';
import 'radar_opacity_slider.dart';

/// `動畫播放` card. [playback] null = controls disabled (loading, or a source
/// without a frame history); [loading] shows a skeleton in place of the slider.
/// [opacity] (the [RadarOpacitySlider], or its error banner) sits at the very
/// bottom, below a hairline, outside 播放設定.
class PlaybackCard extends StatelessWidget {
  const PlaybackCard({super.key, required this.meta, this.playback, this.loading = false, this.opacity});

  final String meta;
  final PlaybackFrames? playback;
  final bool loading;
  final Widget? opacity;

  @override
  Widget build(BuildContext context) {
    final bottom = opacity;
    return Semantics(
      label: '雷達動畫播放',
      container: true,
      child: AppCard(
        title: '動畫播放',
        meta: meta,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.s16,
          children: [
            PlaybackBody(playback: playback, loading: loading),
            if (bottom != null)
              Container(
                padding: const EdgeInsets.only(top: AppSpace.s16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppPalette.stroke3, width: AppStroke.thin)),
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// Time row, controls, timeline and 播放設定 without a card around them; shared
/// by [PlaybackCard] and the 雨量 page's 累積雨量 card.
class PlaybackBody extends StatelessWidget {
  const PlaybackBody({super.key, required this.playback, this.loading = false});

  final PlaybackFrames? playback;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final playback = this.playback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s16,
      children: [
        if (playback != null) _TimeRow(playback),
        _Controls(playback: playback, loading: loading),
        if (playback != null) ...[
          _Timeline(playback),
          _Settings(playback),
        ],
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow(this.playback);

  final PlaybackFrames playback;

  @override
  Widget build(BuildContext context) {
    final count = playback.slots.length;
    final isLatest = radarNextReadyIndex(playback.slots, playback.index) == null;
    final hours = playback.window.inHours;
    // Wraps the caption under the time when both do not fit on one line.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s4,
      children: [
        Text(
          (playback.timeText ?? formatTaiwanMonthDayClock)(playback.slots[playback.current].time),
          style: AppType.subtitle2.copyWith(
            color: AppPalette.foreground1,
            fontWeight: FontWeight.w600,
            fontFeatures: AppType.tabular,
          ),
        ),
        Text(
          playback.buffering
              ? '緩衝中…'
              : '第 ${playback.index + 1} / $count 張 · ${isLatest ? '最新' : playback.timeText != null ? '累積中' : '過去 $hours 小時'}',
          style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.playback, required this.loading});

  final PlaybackFrames? playback;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final playback = this.playback;
    final last = playback == null ? 0 : playback.slots.length - 1;
    final previous = playback == null ? null : radarPreviousReadyIndex(playback.slots, playback.index);
    final next = playback == null ? null : radarNextReadyIndex(playback.slots, playback.index);
    return Row(
      spacing: AppSpace.s8,
      children: [
        AppIconButton(
          icon: Icons.skip_previous,
          tooltip: '上一張',
          onPressed: previous == null ? null : () => playback!.onSeek(playback.slots[previous].time),
        ),
        IconButton.filled(
          tooltip: playback != null && playback.playing ? '暫停' : '播放',
          icon: Icon(playback != null && playback.playing ? Icons.pause : Icons.play_arrow, size: AppSize.icon20),
          onPressed: playback?.onTogglePlay,
          style: IconButton.styleFrom(
            backgroundColor: AppPalette.brandBackground,
            foregroundColor: AppPalette.foregroundOnBrand,
            disabledBackgroundColor: AppPalette.backgroundDisabled,
            disabledForegroundColor: AppPalette.foregroundDisabled,
            fixedSize: const Size.square(AppSize.touch),
          ),
        ),
        AppIconButton(
          icon: Icons.skip_next,
          tooltip: '下一張',
          onPressed: next == null ? null : () => playback!.onSeek(playback.slots[next].time),
        ),
        Expanded(
          child: loading
              ? const Skeleton(height: AppSize.sliderThumb)
              : SliderTheme(
                  data: radarSliderTheme.copyWith(
                    disabledActiveTrackColor: AppPalette.backgroundDisabled,
                    disabledInactiveTrackColor: AppPalette.backgroundDisabled,
                    disabledThumbColor: AppPalette.foregroundDisabled,
                  ),
                  child: Slider(
                    min: 0,
                    max: last.toDouble(),
                    divisions: last > 0 ? last : null,
                    value: (playback?.index ?? 0).toDouble(),
                    semanticFormatterCallback: (_) => '影格時間',
                    // Pending / failed times have no frame: the thumb stays on the shown one.
                    onChanged: playback == null || last == 0
                        ? null
                        : (v) {
                            if (playback.isSlotReady(v.round())) playback.onSeek(playback.slots[v.round()].time);
                          },
                  ),
                ),
        ),
      ],
    );
  }
}

/// `.timeline`: one button per past frame, the current one highlighted and
/// kept in view.
class _Timeline extends StatefulWidget {
  const _Timeline(this.playback);

  final PlaybackFrames playback;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealCurrent(Duration.zero);
  }

  @override
  void didUpdateWidget(_Timeline old) {
    super.didUpdateWidget(old);
    if (old.playback.current != widget.playback.current) _revealCurrent(AppMotion.fast);
  }

  void _revealCurrent(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final buttonContext = _currentKey.currentContext;
      if (buttonContext == null) return;
      // Nearest scrollable only: Scrollable.ensureVisible would also scroll the page.
      Scrollable.of(buttonContext).position.ensureVisible(
        buttonContext.findRenderObject()!,
        alignment: 0.5,
        duration: duration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: AppSpace.s8,
        children: [
          for (var i = 0; i < playback.slots.length; i++)
            _TimelineFrame(
              key: i == playback.current ? _currentKey : null,
              slot: playback.slots[i],
              current: i == playback.current,
              onTap: () => playback.onSeek(playback.slots[i].time),
            ),
        ],
      ),
    );
  }
}

/// One timeline cell: ready = tappable with the strongest-echo bar; pending =
/// dimmed; failed = marked in the danger colour. Neither of the latter has a
/// frame to seek to.
class _TimelineFrame extends StatelessWidget {
  const _TimelineFrame({super.key, required this.slot, required this.current, required this.onTap});

  final RadarSlot slot;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, stroke, label, bar) = switch (slot.state) {
      _ when current => (AppPalette.brandBackgroundSubtle, AppPalette.brandStroke, AppPalette.brandForegroundStrong, _barColour),
      RadarSlotState.ready => (AppPalette.background1, AppPalette.stroke2, AppPalette.foreground2, _barColour),
      RadarSlotState.pending => (AppPalette.backgroundDisabled, AppPalette.strokeDisabled, AppPalette.foregroundDisabled, AppPalette.strokeDisabled),
      RadarSlotState.failed => (AppPalette.dangerBackground, AppPalette.dangerStroke, AppPalette.dangerForeground, AppPalette.dangerSolid),
    };
    return Semantics(
      label: switch (slot.state) {
        RadarSlotState.ready => null,
        RadarSlotState.pending => '尚未載入',
        RadarSlotState.failed => '無法取得',
      },
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          side: BorderSide(color: stroke, width: AppStroke.thin),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: slot.state == RadarSlotState.ready ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: AppSize.icon48, minHeight: AppSize.touch),
            padding: const EdgeInsets.all(AppSpace.s8),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s4,
              children: [
                Text(
                  clockText(slot.time),
                  style: AppType.caption1.copyWith(
                    color: label,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    fontFeatures: AppType.tabular,
                  ),
                ),
                Container(
                  width: AppSize.icon24,
                  height: AppSize.sliderTrack,
                  decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Strongest-echo colour of a ready frame; neutral without significant echo.
  Color get _barColour => switch (slot.frame?.significantDbz) {
    final dbz? => radarDbzColour(dbz),
    null => AppPalette.stroke2,
  };
}

/// `.pb-settings`: expandable 播放設定 (回看範圍, 播放速度, 重複播放).
class _Settings extends StatefulWidget {
  const _Settings(this.playback);

  final PlaybackFrames playback;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final hours = playback.window.inHours;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.background2,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppPalette.stroke3, width: AppStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.small),
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSize.touch),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              child: Row(
                spacing: AppSpace.s8,
                children: [
                  const Icon(Icons.tune, size: AppSize.icon20, color: AppPalette.foreground1),
                  Text(
                    '播放設定',
                    style: AppType.body1.copyWith(color: AppPalette.foreground1, fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Text(
                      '$hours 小時 · ${playback.framesPerSecond} fps · ${playback.repeat ? '重複' : '不重複'}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption1.copyWith(color: AppPalette.foreground3, fontFeatures: AppType.tabular),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: AppMotion.normal,
                    curve: AppMotion.easyEase,
                    child: const Icon(Icons.chevron_right, size: AppSize.icon16, color: AppPalette.foreground3),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s12, AppSpace.s4, AppSpace.s12, AppSpace.s16),
              // One column in a narrow pane; the fields sit side by side once the card is wide enough for two.
              child: AppGrid(
                minColumnWidth: AppLayout.paneMinimumWidth,
                children: [
                  if (playback.windowOptions.isNotEmpty)
                    _Field(
                      label: '回看範圍',
                      child: Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          for (final w in playback.windowOptions)
                            AppChip(
                              label: '${w.inHours} 小時',
                              selected: playback.window == w,
                              onTap: () => playback.onWindow!(w),
                            ),
                        ],
                      ),
                    ),
                  _Field(
                    label: '播放速度（fps）',
                    // Bare numbers: 「12 fps」 would ellipsize in five segments at 360–412 dp.
                    child: AppSegmentedControl<int>(
                      segments: [for (final v in radarFramesPerSecondOptions) (v, '$v')],
                      selected: playback.framesPerSecond,
                      onChanged: playback.onFramesPerSecondChanged,
                    ),
                  ),
                  Row(
                    spacing: AppSpace.s12,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpace.s4,
                          children: [
                            Text('重複播放', style: _fieldLabel),
                            Text(
                              '播放結束後等待 ${radarRepeatPause.inSeconds} 秒再重播',
                              style: AppType.caption1.copyWith(color: AppPalette.foreground3),
                            ),
                          ],
                        ),
                      ),
                      AppSwitch(value: playback.repeat, onChanged: playback.onRepeat, semanticLabel: '重複播放'),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final _fieldLabel = AppType.caption1.copyWith(color: AppPalette.foreground2, fontWeight: FontWeight.w600);

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        Text(label, style: _fieldLabel),
        child,
      ],
    );
  }
}
