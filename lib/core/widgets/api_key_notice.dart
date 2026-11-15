import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_shell.dart' show AppTab, appTabProvider;
import '../api/result.dart' show ApiKeyIssue;
import 'buttons.dart';
import 'status.dart';

/// Replaces a data card or page when the CWA token is missing, rejected or unreadable.
/// 「前往設定」 opens the settings tab where the token is entered.
class ApiKeyNotice extends ConsumerWidget {
  const ApiKeyNotice({super.key, required this.issue});

  final ApiKeyIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StatusBanner(
      tone: StatusTone.error,
      title: '需要 CWA token',
      text: switch (issue) {
        ApiKeyIssue.missing => '尚未設定 CWA token，請到「設定」輸入後即可取得資料。',
        ApiKeyIssue.rejected => 'CWA 拒絕了目前的 token，請到「設定」更新。',
        ApiKeyIssue.unreadable => '無法讀取已儲存的 token，請到「設定」重新輸入。',
      },
      actions: [
        AppButton(
          label: '前往設定',
          variant: AppButtonVariant.primary,
          small: true,
          onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.settings),
        ),
      ],
    );
  }
}
