part of 'hazard_models.dart';

// ============================================================================
// 天氣特報（W-C0033-001 + W-C0033-002）
// ============================================================================

/// 單一縣市的一則生效特報（W-C0033-001），可附上對應公告（W-C0033-002）
class CountyWarning {
  final String phenomena;
  final String significance;
  final DateTime start;
  final DateTime end;

  /// 對應公告；兩資料集分開抓，找不到對應時為 null（不是錯誤）
  final WarningBulletin? bulletin;

  const CountyWarning({
    required this.phenomena,
    required this.significance,
    required this.start,
    required this.end,
    this.bulletin,
  });
}

/// 有生效特報的縣市
class CountyWarnings {
  final String county;
  final List<CountyWarning> warnings;
  const CountyWarnings({required this.county, required this.warnings});
}

/// 一則特報公告（W-C0033-002）
class WarningBulletin {
  /// 公告名稱，如「豪雨特報」
  final String title;
  final DateTime issuedAt;

  /// CWA 最後更新此公告的時間（`datasetInfo.update`）
  final DateTime updatedAt;
  final DateTime start;
  final DateTime end;
  final String description;

  /// 公告涵蓋的縣市／區域名稱（可能含「恆春半島」等非縣市區域）
  final List<String> affectedAreas;

  const WarningBulletin({
    required this.title,
    required this.issuedAt,
    required this.updatedAt,
    required this.start,
    required this.end,
    required this.description,
    required this.affectedAreas,
  });

  factory WarningBulletin.fromJson(Object? json, String path) {
    final m = _asObject(json, path);
    final info = _asObject(m['datasetInfo'], '$path.datasetInfo');
    final valid = _asObject(info['validTime'], '$path.datasetInfo.validTime');
    final hazards = _asList(
      _asObject(_asObject(m['hazardConditions'], '$path.hazardConditions')['hazards'], '$path.hazardConditions.hazards')['hazard'],
      '$path.hazardConditions.hazards.hazard',
    );
    final areas = <String>[
      for (var i = 0; i < hazards.length; i++)
        for (final locationJson in _asList(
          _asObject(_asObject(_asObject(hazards[i], '$path.hazard[$i]')['info'], '$path.hazard[$i].info')['affectedAreas'],
              '$path.hazard[$i].info.affectedAreas')['location'],
          '$path.hazard[$i].info.affectedAreas.location',
        ))
          _asString(_asObject(locationJson, '$path.hazard[$i].location')['locationName'], '$path.hazard[$i].location.locationName'),
    ];
    final content = _asObject(_asObject(m['contents'], '$path.contents')['content'], '$path.contents.content');
    return WarningBulletin(
      title: _asString(info['datasetDescription'], '$path.datasetInfo.datasetDescription'),
      issuedAt: _asInstant(info['issueTime'], '$path.datasetInfo.issueTime'),
      updatedAt: _asInstant(info['update'], '$path.datasetInfo.update'),
      start: _asInstant(valid['startTime'], '$path.datasetInfo.validTime.startTime'),
      end: _asInstant(valid['endTime'], '$path.datasetInfo.validTime.endTime'),
      description: _asString(content['contentText'], '$path.contents.content.contentText').trim(),
      affectedAreas: areas,
    );
  }
}

/// 目前生效的特報。[counties] 為空是合法結果（無生效特報）。
class ActiveWarnings {
  final List<CountyWarnings> counties;
  final List<WarningBulletin> bulletins;

  /// App 取得此資料的時刻（W-C0033-001 的 datastore 回應不含發布時間）
  final DateTime fetchedAt;
  const ActiveWarnings({required this.counties, required this.bulletins, required this.fetchedAt});

  /// 公告中最新的 CWA 更新時間；無公告（無生效特報）為 null
  DateTime? get updatedAt {
    if (bulletins.isEmpty) return null;
    return bulletins.map((b) => b.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// 解析 W-C0033-001（[warningsByCountyRecords] = `records`）；缺 `location` 陣列視為格式錯誤，
  /// 因為此資料集無特報時仍列出全部縣市（hazards 為空陣列）。
  /// [bulletins] 為已解析的 W-C0033-002 公告。
  factory ActiveWarnings.fromJson(Object? warningsByCountyRecords, List<WarningBulletin> bulletins, DateTime fetchedAt) {
    final locations = _asList(_asObject(warningsByCountyRecords, 'records')['location'], 'records.location');
    final counties = <CountyWarnings>[];
    for (var i = 0; i < locations.length; i++) {
      final p = 'records.location[$i]';
      final locationJson = _asObject(locations[i], p);
      final name = _asString(locationJson['locationName'], '$p.locationName');
      final hazards = _asList(_asObject(locationJson['hazardConditions'], '$p.hazardConditions')['hazards'], '$p.hazardConditions.hazards');
      if (hazards.isEmpty) continue;
      final warnings = <CountyWarning>[];
      for (var j = 0; j < hazards.length; j++) {
        final hp = '$p.hazards[$j]';
        final h = _asObject(hazards[j], hp);
        final info = _asObject(h['info'], '$hp.info');
        final valid = _asObject(h['validTime'], '$hp.validTime');
        final start = _asInstant(valid['startTime'], '$hp.validTime.startTime');
        final end = _asInstant(valid['endTime'], '$hp.validTime.endTime');
        warnings.add(CountyWarning(
          phenomena: _asString(info['phenomena'], '$hp.info.phenomena'),
          significance: _asString(info['significance'], '$hp.info.significance'),
          start: start,
          end: end,
          bulletin: _matchBulletin(bulletins, name, start, end),
        ));
      }
      counties.add(CountyWarnings(county: name, warnings: warnings));
    }
    return ActiveWarnings(counties: counties, bulletins: bulletins, fetchedAt: fetchedAt);
  }

  /// 以「縣市在公告區域內＋有效期間完全相同」配對。
  /// 不比對現象名稱：-001 把「大雨」標為「豪雨」，-002 標為「大雨」。
  static WarningBulletin? _matchBulletin(List<WarningBulletin> bulletins, String county, DateTime start, DateTime end) {
    for (final b in bulletins) {
      if (b.affectedAreas.contains(county) && b.start == start && b.end == end) return b;
    }
    return null;
  }
}
