import 'package:flutter/material.dart';

import '../../core/widgets/page_scaffold.dart';

/// 警特報 tab (team-a/warnings.html). Page body is built by the warnings page task.
class WarningsScreen extends StatelessWidget {
  const WarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(header: AppPageHeader(title: '警特報'), children: []);
  }
}
