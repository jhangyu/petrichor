part of 'radar_map_view.dart';

const _attribution = '© OpenStreetMap';

const _pinDot = 9.0;
const _pinHalo = 20.0;
const _pinHaloAlpha = 0.2;
const _pinBorder = 2.0;

/// `.map-chip`: overlay pill with an icon (or spinner) and text.
class _MapChip extends StatelessWidget {
  const _MapChip({this.icon, this.iconColor = AppPalette.foreground1, required this.text, this.spinner = false, this.large = false});

  final IconData? icon;
  final Color iconColor;
  final String text;
  final bool spinner;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final style = (large ? AppType.body1 : AppType.caption1).copyWith(
      color: AppPalette.foreground1,
      fontWeight: FontWeight.w600,
      fontFeatures: AppType.tabular,
    );
    final glyph = icon;
    return Container(
      constraints: BoxConstraints(minHeight: large ? AppSize.touch : AppSize.controlSmall),
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpace.s16 : AppSpace.s12,
        vertical: large ? AppSpace.s8 : AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: AppPalette.backgroundOverlay,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.s4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: large ? AppSpace.s8 : AppSpace.s4,
        children: [
          if (spinner)
            const AppSpinner()
          else if (glyph != null)
            Icon(glyph, size: AppSize.icon16, color: iconColor),
          Text(text, style: style),
        ],
      ),
    );
  }
}

/// Half-transparent backing so the attribution stays legible over the map
/// without drawing attention.
const _attributionBackAlpha = 0.5;

/// OSM licence attribution (OSMF tile policy), kept unobtrusive: a small
/// low-contrast label tucked into the bottom-right corner.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.backgroundOverlay.withValues(alpha: _attributionBackAlpha),
            borderRadius: BorderRadius.circular(AppRadius.extraSmall),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            child: Text(_attribution, style: AppType.caption2.copyWith(color: AppPalette.foreground4)),
          ),
        ),
      ),
    );
  }
}

class _CurrentPlacePin extends StatelessWidget {
  const _CurrentPlacePin();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: _pinHalo,
          height: _pinHalo,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.dangerSolid.withValues(alpha: _pinHaloAlpha),
          ),
        ),
        Container(
          width: _pinDot,
          height: _pinDot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.dangerSolid,
            border: Border.all(color: AppPalette.background1, width: _pinBorder),
          ),
        ),
      ],
    );
  }
}

/// Visual size of the map action buttons: half of [AppSize.touch], icon scaled alike.
/// The tap area stays [AppSize.touch], so the disc sits [_actionHitInset] inside it.
const _actionSize = AppSize.touch / 2;
const _actionIconSize = AppSize.icon24 / 2;
const _actionHitInset = (AppSize.touch - _actionSize) / 2;

/// `.fab` map action (「回到我的位置」, 地圖朝北, lock); disabled when [onPressed] is null.
class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // The fill sits on the shadow's own decoration: a shadow painted over a
    // separate white Material shows through it as grey.
    return Stack(
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.background1,
            boxShadow: enabled ? AppShadows.s4 : AppShadows.s2,
          ),
          child: const SizedBox.square(dimension: _actionSize),
        ),
        // The tap area is the full touch size while the ink radius keeps hover
        // and press feedback inside the disc.
        Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            enabled: enabled,
            child: Material(
              type: MaterialType.transparency,
              child: InkResponse(
                onTap: onPressed,
                radius: _actionSize / 2,
                hoverColor: AppPalette.backgroundHover,
                highlightColor: AppPalette.backgroundPressed,
                child: SizedBox.square(
                  dimension: AppSize.touch,
                  child: Icon(
                    icon,
                    size: _actionIconSize,
                    color: enabled ? AppPalette.foreground2 : AppPalette.foregroundDisabled,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
