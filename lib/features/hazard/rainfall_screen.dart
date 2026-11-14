import 'package:flutter/material.dart';

import '../../core/widgets/page_scaffold.dart';

/// 雨量 tab (team-a/rainfall.html). Page body is built by the rainfall page task.
class RainfallScreen extends StatelessWidget {
  const RainfallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(header: AppPageHeader(title: '雨量'), children: []);
  }
}
