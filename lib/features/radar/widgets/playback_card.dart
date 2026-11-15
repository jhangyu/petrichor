import 'package:flutter/material.dart';

import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/taiwan_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/status.dart';
import '../../../data/radar/radar_loop.dart';
import '../radar_playback.dart';
import '../radar_provider.dart' show radarOpacityMaxPercent, radarOpacityMinPercent, radarOpacityStepPercent;
import 'radar_legend.dart';

const _sliderTheme = SliderThemeData(
  trackHeight: AppSize.sliderTrack,
  activeTrackColor: AppPalette.brandBg,
  inactiveTrackColor: AppPalette.strokeAccessible,
  thumbColor: AppPalette.brandBg,
  overlayColor: AppPalette.brandBgSubtle,
  thumbShape: RoundSliderThumbShape(enabledThumbRadius: AppSize.sliderThumb / 2),
);

/// What the playback card shows once the loop's times are known.
class PlaybackFrames {
  const PlaybackFrames({
    required this.slots,
    required this.index,
    required this.current,
    required this.buffering,
    required this.playing,
    required this.fps,
    required this.repeat,
    required this.window,
    this.windowOptions = const [],
    required this.onTogglePlay,
    required this.onSeek,
    required this.onFps,
    required this.onRepeat,
    this.onWindow,
    this.timeText,
  });

  /// Time-row text of the current slot's time; null = the time itself. An
  /// accumulation frame has no single moment, so its card words the span.
  final String Function(DateTime)? timeText;

  /// Every listed time of the window, oldest first, one timeline cell each
  /// (the source's native cadence, regular or not).
  final List<RadarSlot> slots;

  /// Slot on show (always a ready one).
  final int index;

  /// Highlighted slot and time-row time: the slot playback waits on while
  /// [buffering], else [index].
  final int current;

  /// Playing but stopped at a pending slot (緩衝中).
  final bool buffering;
  final bool playing;
  final int fps;
  final bool repeat;
  final Duration window;

  /// Look-back choices this source offers; empty = the span is fixed elsewhere
  /// and 播放設定 has no 回看範圍.
  final List<Duration> windowOptions;

  /// Null = play disabled (no ready slot).
  final VoidCallback? onTogglePlay;

  /// Called with a ready slot's time only (a time, not an index: the slot list
  /// may be replaced before the screen handles the tap).
  final ValueChanged<DateTime> onSeek;
  final ValueChanged<int> onFps;
  final ValueChanged<bool> onRepeat;
  final ValueChanged<Duration>? onWindow;

  bool _ready(int i) => slots[i].state == RadarSlotState.ready;

  /// Nearest ready slot before / after [index]; null when none.
  int? get previousReady {
    for (var i = index - 1; i >= 0; i--) {
      if (_ready(i)) return i;
    }
    return null;
  }

  int? get nextReady {
    for (var i = index + 1; i < slots.length; i++) {
      if (_ready(i)) return i;
    }
    return null;
  }
}

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
    final f = playback;
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
            PlaybackBody(playback: f, loading: loading),
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
    final f = playback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s16,
      children: [
        if (f != null) _TimeRow(f),
        _Controls(playback: f, loading: loading),
        if (f != null) ...[
          _Timeline(f),
          _Settings(f),
        ],
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow(this.f);

  final PlaybackFrames f;

  @override
  Widget build(BuildContext context) {
    final count = f.slots.length;
    final isLatest = f.nextReady == null;
    final hours = f.window.inHours;
    // Wraps the caption under the time when both do not fit on one line.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s4,
      children: [
        Text(
          (f.timeText ?? formatTaiwanMonthDayClock)(f.slots[f.current].time),
          style: AppType.subtitle2.copyWith(
            color: AppPalette.fg1,
            fontWeight: FontWeight.w600,
            fontFeatures: AppType.tabular,
          ),
        ),
        Text(
          f.buffering
              ? '緩衝中…'
              : '第 ${f.index + 1} / $count 張 · ${isLatest ? '最新' : f.timeText != null ? '累積中' : '過去 $hours 小時'}',
          style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
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
    final f = playback;
    final last = f == null ? 0 : f.slots.length - 1;
    final previous = f?.previousReady;
    final next = f?.nextReady;
    return Row(
      spacing: AppSpace.s8,
      children: [
        AppIconButton(
          icon: Icons.skip_previous,
          tooltip: '上一張',
          onPressed: previous == null ? null : () => f!.onSeek(f.slots[previous].time),
        ),
        IconButton.filled(
          tooltip: f != null && f.playing ? '暫停' : '播放',
          icon: Icon(f != null && f.playing ? Icons.pause : Icons.play_arrow, size: AppSize.icon20),
          onPressed: f?.onTogglePlay,
          style: IconButton.styleFrom(
            backgroundColor: AppPalette.brandBg,
            foregroundColor: AppPalette.fgOnBrand,
            disabledBackgroundColor: AppPalette.bgDisabled,
            disabledForegroundColor: AppPalette.fgDisabled,
            fixedSize: const Size.square(AppSize.touch),
          ),
        ),
        AppIconButton(
          icon: Icons.skip_next,
          tooltip: '下一張',
          onPressed: next == null ? null : () => f!.onSeek(f.slots[next].time),
        ),
        Expanded(
          child: loading
              ? const Skeleton(height: AppSize.sliderThumb)
              : SliderTheme(
                  data: _sliderTheme.copyWith(
                    disabledActiveTrackColor: AppPalette.bgDisabled,
                    disabledInactiveTrackColor: AppPalette.bgDisabled,
                    disabledThumbColor: AppPalette.fgDisabled,
                  ),
                  child: Slider(
                    min: 0,
                    max: last.toDouble(),
                    divisions: last > 0 ? last : null,
                    value: (f?.index ?? 0).toDouble(),
                    semanticFormatterCallback: (_) => '影格時間',
                    // Pending / failed times have no frame: the thumb stays on the shown one.
                    onChanged: f == null || last == 0
                        ? null
                        : (v) {
                            if (f._ready(v.round())) f.onSeek(f.slots[v.round()].time);
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
  const _Timeline(this.f);

  final PlaybackFrames f;

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
    if (old.f.current != widget.f.current) _revealCurrent(AppMotion.fast);
  }

  void _revealCurrent(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx == null) return;
      // Nearest scrollable only: Scrollable.ensureVisible would also scroll the page.
      Scrollable.of(ctx).position.ensureVisible(
        ctx.findRenderObject()!,
        alignment: 0.5,
        duration: duration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: AppSpace.s8,
        children: [
          for (var i = 0; i < f.slots.length; i++)
            _TimelineFrame(
              key: i == f.current ? _currentKey : null,
              slot: f.slots[i],
              current: i == f.current,
              onTap: () => f.onSeek(f.slots[i].time),
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
      _ when current => (AppPalette.brandBgSubtle, AppPalette.brandStroke, AppPalette.brandFgStrong, _barColour),
      RadarSlotState.ready => (AppPalette.bg1, AppPalette.stroke2, AppPalette.fg2, _barColour),
      RadarSlotState.pending => (AppPalette.bgDisabled, AppPalette.strokeDisabled, AppPalette.fgDisabled, AppPalette.strokeDisabled),
      RadarSlotState.failed => (AppPalette.dangerBg, AppPalette.dangerStroke, AppPalette.dangerFg, AppPalette.dangerSolid),
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
  const _Settings(this.f);

  final PlaybackFrames f;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final hours = f.window.inHours;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.bg2,
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
                  const Icon(Icons.tune, size: AppSize.icon20, color: AppPalette.fg1),
                  Text(
                    '播放設定',
                    style: AppType.body1.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Text(
                      '$hours 小時 · ${f.fps} fps · ${f.repeat ? '重複' : '不重複'}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: AppMotion.normal,
                    curve: AppMotion.easyEase,
                    child: const Icon(Icons.chevron_right, size: AppSize.icon16, color: AppPalette.fg3),
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
                minColumnWidth: AppLayout.paneMinWidth,
                children: [
                  if (f.windowOptions.isNotEmpty)
                    _Field(
                      label: '回看範圍',
                      child: Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          for (final w in f.windowOptions)
                            AppChip(
                              label: '${w.inHours} 小時',
                              selected: f.window == w,
                              onTap: () => f.onWindow!(w),
                            ),
                        ],
                      ),
                    ),
                  _Field(
                    label: '播放速度（fps）',
                    // Bare numbers: 「12 fps」 would ellipsize in five segments at 360–412 dp.
                    child: AppSegmented<int>(
                      segments: [for (final v in radarFpsOptions) (v, '$v')],
                      selected: f.fps,
                      onChanged: f.onFps,
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
                              style: AppType.caption1.copyWith(color: AppPalette.fg3),
                            ),
                          ],
                        ),
                      ),
                      AppSwitch(value: f.repeat, onChanged: f.onRepeat, semanticLabel: '重複播放'),
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

final _fieldLabel = AppType.caption1.copyWith(color: AppPalette.fg2, fontWeight: FontWeight.w600);

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

/// `.slider`: 疊圖透明度 10–100 % (the [PlaybackCard.opacity] content).
class RadarOpacitySlider extends StatelessWidget {
  const RadarOpacitySlider({super.key, required this.percent, required this.onChanged});

  final int percent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s4,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('疊圖透明度', style: AppType.body1.copyWith(color: AppPalette.fg1)),
            Text(
              '$percent%',
              style: AppType.body1.copyWith(
                color: AppPalette.fg1,
                fontWeight: FontWeight.w600,
                fontFeatures: AppType.tabular,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: _sliderTheme,
          child: Slider(
            min: radarOpacityMinPercent.toDouble(),
            max: radarOpacityMaxPercent.toDouble(),
            divisions: (radarOpacityMaxPercent - radarOpacityMinPercent) ~/ radarOpacityStepPercent,
            value: percent.toDouble(),
            semanticFormatterCallback: (_) => '疊圖透明度',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final v in const [radarOpacityMinPercent, radarOpacityMaxPercent])
              Text('$v%', style: AppType.caption1.copyWith(color: AppPalette.fg3)),
          ],
        ),
      ],
    );
  }
}
