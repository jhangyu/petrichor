import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_key.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/data_display.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/status.dart';
import 'settings_parts.dart';

/// Token 設定 group: five states (未設定 / 驗證中 / 有效 / 無效 / 無法驗證) plus an unreadable-key reset.
class TokenSettingsCard extends ConsumerStatefulWidget {
  const TokenSettingsCard({super.key});

  @override
  ConsumerState<TokenSettingsCard> createState() => _TokenSettingsCardState();
}

/// What one [ApiKeyStatus] looks like in the card.
typedef _StatusView = ({
  String label,
  BadgeTone tone,
  IconData? icon,
  String secondary,
  String? fieldError,
  String? fieldHelper,
  bool unreadable,
});

_StatusView _view(ApiKeyStatus status) {
  const unverifiedHelp = '授權碼已儲存，但尚未確認是否有效。請確認網路後按「重新驗證」。';
  return switch (status) {
    ApiKeyNotSet() => (
        label: '未設定', tone: BadgeTone.neutral, icon: null, secondary: '尚未輸入',
        fieldError: null, fieldHelper: null, unreadable: false,
      ),
    ApiKeyVerifying() => (
        label: '驗證中', tone: BadgeTone.neutral, icon: null, secondary: '正在向中央氣象署送出一次測試請求…',
        fieldError: null, fieldHelper: null, unreadable: false,
      ),
    ApiKeyValid(:final checkedAt) => (
        label: '有效', tone: BadgeTone.success, icon: Icons.check_circle_outline,
        secondary: '驗證於 ${clockOfMinute(checkedAt.hour * 60 + checkedAt.minute)} · 測試請求成功',
        fieldError: null, fieldHelper: null, unreadable: false,
      ),
    ApiKeyUnchecked() => (
        label: '未驗證', tone: BadgeTone.neutral, icon: null, secondary: '已儲存 · 尚未驗證，按「重新驗證」',
        fieldError: null, fieldHelper: null, unreadable: false,
      ),
    ApiKeyInvalid(kind: ApiKeyInvalidKind.rejected, :final reason) => (
        label: '無效', tone: BadgeTone.danger, icon: Icons.error_outline, secondary: '中央氣象署拒絕此授權碼',
        fieldError: '原因：$reason。授權碼錯誤或已停用，請確認是否完整複製，或到開放平臺重新取得。',
        fieldHelper: null, unreadable: false,
      ),
    ApiKeyInvalid(kind: ApiKeyInvalidKind.unreachable || ApiKeyInvalidKind.unexpected, :final reason) => (
        label: '無法驗證', tone: BadgeTone.warning, icon: Icons.cloud_off_outlined, secondary: '未判定是否有效',
        fieldError: null, fieldHelper: '$reason。$unverifiedHelp', unreadable: false,
      ),
    ApiKeyInvalid(kind: ApiKeyInvalidKind.unreadable) => (
        label: '無法讀取', tone: BadgeTone.danger, icon: Icons.error_outline, secondary: '儲存的授權碼已損毀',
        fieldError: null, fieldHelper: null, unreadable: true,
      ),
  };
}

class _TokenSettingsCardState extends ConsumerState<TokenSettingsCard> {
  /// Label (20) + label→field gap (s8) of [AppTextField]; offsets the wide-layout button onto the field.
  static const _fieldLabelOffset = 20 + AppSpace.s8;

  final _controller = TextEditingController();
  bool _shown = false;
  String? _inputError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _typed => _controller.text.isNotEmpty;

  /// Parse at the boundary, persist, then verify with one real request.
  Future<void> _saveAndVerify() async {
    final CwaApiKey key;
    try {
      key = CwaApiKey.parse(_controller.text);
    } on FormatException catch (e) {
      setState(() => _inputError = '授權碼格式錯誤：${e.message}');
      return;
    }
    setState(() => _inputError = null);
    await ref.read(cwaApiKeyProvider.notifier).save(key);
    if (!mounted) return;
    _controller.clear();
    if (ref.read(cwaApiKeyProvider).hasError) return;
    await ref.read(apiKeyStatusProvider.notifier).verify();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除授權碼？'),
        content: const Text('清除後所有資料頁都會停止更新，直到你重新輸入。'),
        actions: [
          AppButton(label: '取消', variant: AppButtonVariant.subtle, onPressed: () => Navigator.pop(context, false)),
          AppButton(label: '清除', variant: AppButtonVariant.primary, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controller.clear();
    setState(() => _inputError = null);
    await ref.read(cwaApiKeyProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(apiKeyStatusProvider);
    final view = _view(status);
    final verifying = status is ApiKeyVerifying;
    final stored = status is! ApiKeyNotSet && !verifying;
    final brand = status is ApiKeyValid || verifying;
    final fieldError = _inputError ?? view.fieldError;
    final fieldHelper = fieldError == null ? view.fieldHelper : null;

    final field = AppTextField(
      label: '授權碼',
      hint: '貼上 CWA- 開頭的授權碼',
      controller: _controller,
      prefixIcon: Icons.lock_outline,
      obscureText: !_shown,
      readOnly: verifying,
      errorText: fieldError,
      helperText: fieldHelper,
      helperColor: AppPalette.warningFg,
      onChanged: (_) => setState(() {}),
      suffix: AppIconButton(
        icon: _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        tooltip: _shown ? '隱藏授權碼' : '顯示授權碼',
        onPressed: () => setState(() => _shown = !_shown),
      ),
    );
    final save = AppButton(
      label: '儲存並驗證',
      variant: AppButtonVariant.primary,
      onPressed: _typed && !verifying ? _saveAndVerify : null,
    );
    final secondary = [
      AppButton(
        label: '重新驗證',
        onPressed: stored && !view.unreadable ? () => ref.read(apiKeyStatusProvider.notifier).verify() : null,
      ),
      AppButton(
        label: '清除',
        variant: AppButtonVariant.subtle,
        onPressed: stored ? _confirmClear : null,
      ),
    ];

    return SettingsGroup(
      title: 'Token 設定',
      meta: view.label,
      body: AppList(children: [
          Semantics(
            liveRegion: true,
            child: AppListRow(
              leading: SettingsTint(icon: Icons.key_outlined, brand: brand),
              primary: '中央氣象署 API 授權碼',
              secondary: view.secondary,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpace.s8,
                children: [
                  if (verifying) const AppSpinner(),
                  AppBadge(label: view.label, tone: view.tone, icon: view.icon),
                ],
              ),
            ),
          ),
          SettingsBlock(children: [
                if (view.unreadable)
                  StatusBanner(
                    tone: StatusTone.error,
                    title: '無法讀取已儲存的授權碼',
                    text: (status as ApiKeyInvalid).reason,
                    actions: [
                      AppButton(
                        label: '清除並重新輸入',
                        small: true,
                        onPressed: () => ref.read(cwaApiKeyProvider.notifier).clear(),
                      ),
                    ],
                  ),
                LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth < AppLayout.cardWideWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpace.s16,
                        children: [field, Row(spacing: AppSpace.s8, children: [save, ...secondary])],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpace.s16,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpace.s12,
                          children: [
                            Expanded(child: field),
                            Padding(padding: const EdgeInsets.only(top: _fieldLabelOffset), child: save),
                          ],
                        ),
                        Row(spacing: AppSpace.s8, children: secondary),
                      ],
                    );
                  },
                ),
                SelectableText(
                  '申請方式：到「中央氣象署氣象資料開放平臺」opendata.cwa.gov.tw 註冊會員並登入，'
                  '在會員資訊頁取得「API 授權碼」，複製後貼到上方欄位。',
                  style: AppType.caption1.copyWith(color: AppPalette.fg3),
                ),
          ]),
        ]),
      note: const SettingsNote(icon: Icons.lock_outline, text: '授權碼只存在這台裝置，只用來向中央氣象署請求資料。'),
    );
  }
}
