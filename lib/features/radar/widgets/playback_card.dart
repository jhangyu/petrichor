import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/choices.dart';
import '../../../core/widgets/status.dart';
import '../radar_playback.dart';

/// What the playback card shows once frames exist.
class PlaybackFrames {
  const PlaybackFrames({
    required this.times,
    required this.index,
    required this.playing,
    required this.fps,
    required this.repeat,
    required this.windowFrames,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onFps,
    required this.onRepeat,
    required this.onWindowFrames,
  });

  /// Observation time of every frame, oldest first.
  final List<DateTime> times;
  final int index;
  final bool playing;
  final int fps;
  final bool repeat;
  final int windowFrames;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSeek;
  final ValueChanged<int> onFps;
  final ValueChanged<bool> onRepeat;
  final ValueChanged<int> onWindowFrames;
}

/// `動畫播放` card. [frames] null = controls disabled (loading, or a source
/// without a frame history); [loading] shows a skeleton in place of the slider.
class PlaybackCard extends StatelessWidget {
  const PlaybackCard({super.key, required this.meta, this.frames, this.loading = false});

  final String meta;
  final PlaybackFrames? frames;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final f = frames;
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
            if (f != null) _TimeRow(f),
            _Controls(frames: f, loading: loading),
            if (f != null) ...[
              _Timeline(f),
              _Settings(f),
              Text(
                '影格為中央氣象署網站帶時間戳的雷達圖，每 10 分鐘一張，最多可回看 24 小時（144 張）。',
                style: AppType.caption1.copyWith(color: AppPalette.fg3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow(this.f);

  final PlaybackFrames f;

  @override
  Widget build(BuildContext context) {
    final count = f.times.length;
    final isLatest = f.index == count - 1;
    final hours = f.windowFrames ~/ radarFramesPerHour;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatTaiwanMonthDayClock(f.times[f.index]),
          style: AppType.subtitle2.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600, fontFeatures: AppType.tabular),
        ),
        Text(
          '第 ${f.index + 1} / $count 張 · ${isLatest ? '最新' : '過去 $hours 小時'}',
          style: AppType.caption1.copyWith(color: AppPalette.fg3, fontFeatures: AppType.tabular),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.frames, required this.loading});

  final PlaybackFrames? frames;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final f = frames;
    final last = f == null ? 0 : f.times.length - 1;
    return Row(
      spacing: AppSpace.s4,
      children: [
        AppIconButton(
          icon: Icons.skip_previous,
          tooltip: '上一張',
          onPressed: f == null || f.index == 0 ? null : () => f.onSeek(f.index - 1),
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
          onPressed: f == null || f.index == last ? null : () => f.onSeek(f.index + 1),
        ),
        Expanded(
          child: loading
              ? const Skeleton(height: AppSize.sliderThumb)
              : SliderTheme(
                  data: SliderThemeData(
                    trackHeight: AppSize.sliderTrack,
                    activeTrackColor: AppPalette.brandBg,
                    inactiveTrackColor: AppPalette.strokeAccessible,
                    thumbColor: AppPalette.brandBg,
                    disabledActiveTrackColor: AppPalette.bgDisabled,
                    disabledInactiveTrackColor: AppPalette.bgDisabled,
                    disabledThumbColor: AppPalette.fgDisabled,
                    overlayColor: AppPalette.brandBgSubtle,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppSize.sliderThumb / 2),
                  ),
                  child: Slider(
                    min: 0,
                    max: last.toDouble(),
                    divisions: last > 0 ? last : null,
                    value: (f?.index ?? 0).toDouble(),
                    semanticFormatterCallback: (_) => '影格時間',
                    onChanged: f == null || last == 0 ? null : (v) => f.onSeek(v.round()),
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
    if (old.f.index != widget.f.index) _revealCurrent(AppMotion.fast);
  }

  void _revealCurrent(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: duration);
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
          for (var i = 0; i < f.times.length; i++)
            _TimelineFrame(
              key: i == f.index ? _currentKey : null,
              label: formatTaiwanClock(f.times[i]),
              current: i == f.index,
              onTap: () => f.onSeek(i),
            ),
        ],
      ),
    );
  }
}

class _TimelineFrame extends StatelessWidget {
  const _TimelineFrame({super.key, required this.label, required this.current, required this.onTap});

  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: current ? AppPalette.brandBgSubtle : AppPalette.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: current ? AppPalette.brandStroke : AppPalette.stroke2, width: AppStroke.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: AppSize.icon48, minHeight: AppSize.touch),
          padding: const EdgeInsets.all(AppSpace.s8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.caption1.copyWith(
              color: current ? AppPalette.brandFgStrong : AppPalette.fg2,
              fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: AppType.tabular,
            ),
          ),
        ),
      ),
    );
  }
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
    final hours = f.windowFrames ~/ radarFramesPerHour;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.bg2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppPalette.stroke3, width: AppStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSize.touch),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              child: Row(
                spacing: AppSpace.s8,
                children: [
                  const Icon(Icons.tune, size: AppSize.icon20, color: AppPalette.fg1),
                  Text('播放設定', style: AppType.body1.copyWith(color: AppPalette.fg1, fontWeight: FontWeight.w600)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.s16,
                children: [
                  _Field(
                    label: '回看範圍',
                    child: Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        for (final h in radarWindowHourOptions)
                          AppChip(
                            label: '$h 小時',
                            selected: f.windowFrames == h * radarFramesPerHour,
                            onTap: () => f.onWindowFrames(h * radarFramesPerHour),
                          ),
                      ],
                    ),
                  ),
                  _Field(
                    label: '播放速度',
                    child: AppSegmented<int>(
                      segments: [for (final v in radarFpsOptions) (v, '$v fps')],
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
                      Switch(
                        value: f.repeat,
                        onChanged: f.onRepeat,
                        activeThumbColor: AppPalette.bg1,
                        activeTrackColor: AppPalette.brandBg,
                        inactiveThumbColor: AppPalette.bg1,
                        inactiveTrackColor: AppPalette.strokeAccessible,
                        trackOutlineColor: const WidgetStatePropertyAll(AppPalette.transparent),
                      ),
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
      children: [Text(label, style: _fieldLabel), child],
    );
  }
}
