import 'package:flutter/material.dart';

import '../../core/widgets/page_scaffold.dart';

/// 地點 tab (team-a/location.html). Page body is built by the location page task.
class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(header: AppPageHeader(title: '地點'), children: []);
  }
}
