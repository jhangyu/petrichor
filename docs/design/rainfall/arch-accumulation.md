# 累積雨量 layer: fetch and accumulation strategy

Measured 2026-11-15 (UTC 11:26 onward). Scripts, downloads and raw logs: `.claude/tmp/accum-strategy/` (`probe.sh`, `compare.py`, `diag*.py`, `model.py`, `tls_check.dart`, `*.log`, `model.md`).

## Recommendation (summary)

- **Native-window composition.** Build each frame from the fewest QPEplus gauge rolling-window grids that end at the frame time or at whole hours before it. Use the largest window first: 1 = 1h, 2 = 1h+1h, 3 = 3h, 4 = 3h+1h, 6 = 6h, 12 = 12h, 24 = 24h, 48 = 24h+24h, 168 = 7×24h.
- Keep the **10-minute step** (frozen user decision 3). Set the playback span (look-back) options to **1/2/4/6 h** (the radar options up to 6 h), with a **default of 2 h**.
- Load the **newest frame first**, then oldest → newest, the same as the radar. Cache the downloaded grids (shared across windows), and cache the rendered frames as WebP.
- Cost with a 6 h span: the worst window (168 h) costs 7 requests for the first frame and 252 for a cold full span. That is about 4.9 MB on the wire typical, 5.8 MB in heavy rain (27–33 MB uncompressed), or about 4 s at 4 parallel requests. Each 10-minute update costs 7 requests (+1 revalidation). Every window of 24 h or less costs ≤ 72 requests and ≤ 1.7 MB on the wire cold, and 1–2 requests per update.
- The result equals QPEplus's own native grids exactly, because 6h = 3h+3h and 24h = 12h+12h hold bit-for-bit in the archive. Summing 1-hour grids does not always do so (see §2).

## 1. Native gauge windows: URL patterns (verified)

Pattern (times UTC; the minute is a multiple of 10; `W` without zero padding in the file name, zero-padded to 2 digits in the folder name):

```
https://qpeplus.cwa.gov.tw/static/data/grid/raingage/rain{WW}h_gage/{YYYY}/{MM}/{DD}/{hh}/GAGE_PCP_{W}H.{YYYYMMDD}.{hhmm}.dat
```

The native windows are W ∈ {1, 3, 6, 12, 24}. This is the full gauge list in `webmap_json` (`.claude/tmp/history-hourly/qpe/wj.json`). Every window is a rolling window that ends at the file time. The format is identical to the 1 h file: a 441×561 CSR grid, raw × 0.25 mm, with the south row first.

Status evidence (`probe1.log`, curl, no cookie). Each line shows the code, the bytes, and the frame time:

| W | 2026-11-15 10:50Z | 10:40Z | 10:30Z | heavy rain: Typhoon Kong-rey 2024-10-31 06:00Z |
|---|---|---|---|---|
| 1 h | 200, 16 994 B | 200, 18 573 | 200, 18 946 | 200, 105 316 |
| 3 h | 200, 26 280 | 200, 27 491 | 200, 27 619 | 200, 130 562 |
| 6 h | 200, 30 340 | 200, 31 255 | 200, 31 644 | 200, 154 369 |
| 12 h | 200, 49 203 | 200, 49 460 | 200, 50 936 | 200, 159 277 |
| 24 h | 200, 128 830 | 200, 130 468 | 200, 132 147 | 200, 160 279 |

Negative controls (404, text/html, 146 B): `rain02h_gage` / `GAGE_PCP_2H`, `rain04h_gage`, `rain48h_gage`, `rain72h_gage`, and the off-grid minute `GAGE_PCP_1H.20261115.1055`. So 2, 4, 48 and 168 h have to be composed. A further 60 files of history (2024-10-30/31 and 2026-11-08…15) all returned 200 (`probe2/3/4.log`).

File sizes in bytes, uncompressed (`sizes.log`). "Typical" is 2026-11-14/15 with light-to-moderate rain (n = 3–35 per product). "Heavy" is the Kong-rey typhoon, 2024-10-30/31.

| product | typical median (min–max) | heavy median (max) |
|---|---|---|
| 1 h | 17 KB (1.9–80) | 82 KB (138) |
| 3 h | 27 KB (2.8–101) | 97 KB (151) |
| 6 h | 31 KB | 154 KB |
| 12 h | 50 KB (49–122) | 126 KB (159) |
| 24 h | 131 KB (129–145) | 109 KB (160) |

**Transfer is gzip.** The server answers `Content-Encoding: gzip`. On `GAGE_PCP_24H.20241031.0600` the transfer was 36 149 B on the wire against 160 279 B uncompressed (`gzip.log`). Dart's `HttpClient` (and so dio on native) asks for gzip by default, and the check returned `compressionState = decompressed` (`tls.log`). "Wire" figures below are local gzip −6 × 1.145 (that ratio is measured against the server).

Latency from this host (`latency.log`) is 52–89 ms per request on a new connection and 28–45 ms on a reused connection.

Colour scales: QPEplus publishes one per window (`/static/data/csv_header/cb_rain{01,24,72}h_rad_gc.txt`, all 200, copies in `hdr/`). In mm:
- 1 h: 1, 2, 5, 10, 15, 20, 30, 40, 50, 80, 100, 150, 200, 250.
- 24 h: 1, 10, 20, 30, 50, 70, 100, 130, 160, 200, 250, 350, 450, 600, 800.
- 72 h: 1, 10, 20, 40, 60, 80, 100, 150, 200, 300, 400, 500, 600, 800, 1000.

All three use the same 15 colours. The choice of scale per window belongs to the design.

## 2. Sum of 1-hour grids vs native windows (`compare.log`, `diag*.log`)

Max and mean absolute difference in mm. "Wet" means cells where either side is > 0.

| frame | check | wet cells | cells differing | max \|diff\| | mean \|diff\| (wet) |
|---|---|---|---|---|---|
| 2026-11-15 10:50Z | 3h = 1h@T + 1h@T−1 + 1h@T−2 | 3 805 | 0 | 0.00 | 0.0000 |
| 2026-11-15 10:50Z | 24h = 24 × 1h | 18 928 | 0 | 0.00 | 0.0000 |
| 2026-11-15 10:50Z | 24h = 8 × 3h = 12h + 12h | 18 928 | 0 | 0.00 | 0.0000 |
| 2026-11-15 10:50Z | 3h at T−3…T−21 h (8 windows) vs their 1h triples | — | 0 in all 8 | 0.00 | 0.0000 |
| 2026-11-08, -12, -14 | 3h vs 1h ×3 | 126–591 | 0 | 0.00 | 0.0000 |
| typhoon 2024-10-31 06:00Z | 3h = 1h ×3 (newest triple) | 17 581 | 0 | 0.00 | 0.0000 |
| typhoon | 6h = 3h@T + 3h@T−3 | 20 112 | 0 | 0.00 | 0.0000 |
| typhoon | 24h = 12h@T + 12h@T−12 | 20 198 | 0 | 0.00 | 0.0000 |
| typhoon | 24h = 24 × 1h | 20 256 | 6 734 | **127.25** (native max 1006) | 1.34 |
| typhoon | 24h = 8 × 3h | 20 202 | 5 368 | 82.50 | 0.50 |
| typhoon | 3h at T−3 h vs its 1h triple (worst of 7 older triples) | 20 181 | 5 768 | 46.25 | 0.61 |

Reading:
- In the current week, 1-hour sums equal the native windows bit for bit.
- In the 2024 typhoon archive, the native multi-hour windows chain exactly with each other. But the archived 1-hour grids no longer add up to the archived 3h/24h grids, by up to 127 mm (12.6 %) over 24 h. Likely cause (not proven): during heavy rain, late gauge data re-ran the 1 h grids after the longer windows were written. It may also have been a later re-run of the archive.
- Effect on the design: composing from native windows reproduces what QPEplus shows for 3/6/12/24 h by construction. A 1-hour sum, or anything that mixes products such as an add/subtract recurrence, can drift from QPEplus during exactly the events users care about, and a subtraction could even go negative.

## 3. Strategies and cost per window

Model: `model.py` builds, for every frame, the set of (product, end time) pieces it needs. "Cold" is the union over the span. "Update" is the set the next newest frame needs that the cache lacks. "(+1)" is one revalidation of the previous newest frame's offset-0 grid, which QPEplus rewrites once 4–10 min after it first appears (history-hourly.md). Sizes are the medians in §1. Each cell gives requests / KB uncompressed / KB wire. Full tables for both spans, both regimes and all strategies are in `.claude/tmp/accum-strategy/model.md`.

Candidates:
- **A. Native composition** (recommended): the pieces per frame are listed in the summary.
- **B. Sliding sum of shared 1 h grids**: a frame needs W 1-hour grids. Frames of the same 10-minute phase share them, so a cold span needs F + 6(W−1) files.
- **C. Hybrid recurrence**: one native-composed base frame per 10-minute phase, then older frames by A(t−1h) = A(t) − 1h(t) + 1h(t−W). This mixes products.
- **D. Coarser step**: 60-minute frames for long windows (native composition).
- **E. Lazy/progressive**: this is an ordering, not a download set. The newest frame comes first (column a), then the rest in playback order. Adopted on top of A.

### A. Native composition, 10-min step, span 6 h (36 frames)

| W | pieces/frame | (a) first frame typical | (a) heavy | (b) cold span typical | (b) heavy | (c) per update (+reval), wire typical / heavy |
|---|---|---|---|---|---|---|
| 1 h | 1 | 1 / 17 / 2 | 1 / 82 / 12 | 36 / 625 / 90 | 36 / 2 943 / 433 | 1 (+1) / 2 / 12 KB |
| 2 h | 2 | 2 / 35 / 5 | 2 / 164 / 24 | 42 / 729 / 105 | 42 / 3 434 / 505 | 1 (+1) / 2 / 12 KB |
| 3 h | 1 | 1 / 27 / 4 | 1 / 97 / 17 | 36 / 961 / 149 | 36 / 3 481 / 615 | 1 (+1) / 4 / 17 KB |
| 4 h | 2 | 2 / 44 / 7 | 2 / 178 / 29 | 72 / 1 586 / 239 | 72 / 6 425 / 1 047 | 2 (+1) / 7 / 29 KB |
| 6 h | 1 | 1 / 31 / 5 | 1 / 154 / 32 | 36 / 1 125 / 190 | 36 / 5 557 / 1 141 | 1 (+1) / 5 / 32 KB |
| 12 h | 1 | 1 / 50 / 8 | 1 / 126 / 27 | 36 / 1 807 / 286 | 36 / 4 529 / 962 | 1 (+1) / 8 / 27 KB |
| 24 h | 1 | 1 / 131 / 19 | 1 / 109 / 23 | 36 / 4 727 / 699 | 36 / 3 931 / 828 | 1 (+1) / 19 / 23 KB |
| 48 h | 2 | 2 / 263 / 39 | 2 / 218 / 46 | 72 / 9 454 / 1 397 | 72 / 7 861 / 1 656 | 2 (+1) / 39 / 46 KB |
| 168 h | 7 | 7 / 919 / 136 | 7 / 764 / 161 | 252 / 33 089 / 4 891 | 252 / 27 515 / 5 794 | 7 (+1) / 136 / 161 KB |

### A. Native composition, span 2 h (12 frames, the proposed default)

The first frame (a) and the update cost (c) are the same as in the 6 h table.

| W | 1 | 2 | 3 | 4 | 6 | 12 | 24 | 48 | 168 |
|---|---|---|---|---|---|---|---|---|---|
| (b) cold requests | 12 | 18 | 12 | 24 | 12 | 12 | 12 | 24 | 84 |
| (b) wire typical / heavy KB | 30 / 144 | 45 / 216 | 50 / 205 | 80 / 349 | 63 / 380 | 95 / 321 | 233 / 276 | 466 / 552 | 1 630 / 1 931 |

### B. Sliding 1 h sum, span 6 h (heavy)

| W | 1 | 2 | 3 | 4 | 6 | 12 | 24 | 48 | 168 |
|---|---|---|---|---|---|---|---|---|---|
| (a) first frame requests | 1 | 2 | 3 | 4 | 6 | 12 | 24 | 48 | **168** |
| (b) cold requests | 36 | 42 | 48 | 54 | 66 | 102 | 174 | 318 | **1 038** |
| (b) wire KB | 433 | 505 | 577 | 649 | 793 | 1 226 | 2 092 | 3 823 | 12 478 |
| (c) per update | 1 (+1) | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |

B is cheapest per update, but each frame needs 24–168 requests for W ≥ 24 h, and the result can drift from the native grids (§2). Rejected.

### C. Hybrid recurrence, span 6 h (heavy)

The cold requests for W = 3…24 h are 54–66, which is *more* than A's 36. Only the long windows gain: 168 h needs 102 requests (A: 252) and 1.7 MB on the wire (A: 5.8 MB), with 9 (+1) per update. Rejected: the saving is limited to 168 h, and it mixes the 1 h product with the 24 h product, the same pair that disagreed by up to 127 mm in the typhoon archive.

### D. Coarser 60-min step for 48/168 h, span 6 h

168 h needs 42 requests cold (A: 252), 48 h needs 12 (A: 72), and there is one update per hour. This contradicts frozen decision 3 (10-minute step). It is listed as the fallback if 252 requests for 168 h × 6 h ever proves too slow on mobile. This is the user's decision, not a default.

### Why A

- It is exact (it equals QPEplus's native grids).
- It has the lowest first-frame cost for every window except 2 h, where it ties with B.
- Cold cost is ≤ 72 requests and ≤ 1.7 MB on the wire for every window except 168 h, and 168 h stays at about 5–6 MB / 252 requests for the largest span (84 requests / ≤ 2 MB at the default 2 h span).
- A cache of grids shared across windows makes window switches cheap. For example, 24 h → 48 h at a 6 h span reuses the 36 cached 24h grids and fetches 36 more.

Request budget: 252 requests × ~60 ms ÷ 4 parallel (`radarFetchWorkers`) ≈ 4 s. The newest frame appears after 7 requests, about 0.1–0.2 s.

## 4. Dart TLS reachability (`tls.log`)

`dart run .claude/tmp/accum-strategy/tls_check.dart` (Dart 3.12.2, macOS arm64, `dart:io HttpClient`, default trust store) returned RC=0:
- `200 16994B` for `GAGE_PCP_1H.20261115.1050.dat`
- `200 128830B` for `GAGE_PCP_24H.20261115.1050.dat`
- issuer `TWCA SSL Certification Authority`, subject CN `qpeplus.cwa.gov.tw`, body starting `441,561,c,118.00,…`
- gzip negotiated (`decompressed`).

Dart accepts the chain on macOS; Python 3.14's urllib rejects it. Android, iOS and Windows trust stores were not tested (see uncertainties).

## 5. Settings model

Reuse the radar settings classes (`lib/features/radar/radar_provider.dart`). Add one group to `RadarGroup` in `radar_playback.dart`:

```dart
rainfall(defaultWindow: Duration(hours: 2), defaultFps: 8),
```

This gives, without new setting classes:

| setting | storage key (int) | options | default |
|---|---|---|---|
| speed (fps) | `radar.rainfall.fps` | `radarFpsOptions` = 2, 4, 8, 12, 24 | 8 |
| repeat | `radar.rainfall.repeat` | 1 / 0 | 1 (on) |
| playback span (look-back) | `radar.rainfall.windowMinutes` | `radarWindowOptions` capped by the source's `maxWindow = 6 h` → 60, 120, 240, 360 | 120 |

There is one new setting, the accumulation window: `RainAccumWindow extends IntSetting<int>`, key `rainfall.accumWindowHours`, options `[1, 2, 3, 4, 6, 12, 24, 48, 168]`, default 24 (the design may change this default). A corrupt stored value surfaces as `StoredSettingException`, the same as the radar.

Opacity: not proposed (YAGNI). If design 3 shows an opacity slider, `RadarOpacity(RadarGroup.rainfall)` already gives `radar.rainfall.opacity`.

Naming: the `radar.` key prefix and `Radar*` type names now also cover rainfall. A rename to `Playback*` / `playback.<group>.*` is allowed (unreleased, no migration needed) but touches files the other session is editing, so it goes to the parking lot.

## 6. Data-layer shape (reusing the radar pipeline)

The radar pipeline already does: frame list → newest first, then oldest first → Pool(4) downloads → Pool(2) isolate processing → lossless WebP cache → `Stream<RadarLoop>` of `RadarSlot`s → `radarNextStep` / `PlaybackCard` / the map overlay. The accumulation layer plugs into the same pipeline. It does not get a parallel copy.

- **Frame list (deterministic, no list file):** newest = floor(now − 6 min, 10 min) in UTC. If the offset-0 grid of that time returns 404, step back one 10-minute slot (only once; a second 404 is a failed slot). Frames are the span ending at newest, oldest first (`selectRadarFrameWindow` already does this).
- **Pieces:** `accumPieces(W)` gives a list of (native hours, offset hours), greedy largest first. `accumPieceUrl(native, endUtc)` gives the URL in §1.
- **Piece cache:** `<appCache>/rain_accum_pieces_v1/<WW>h/<yyyyMMddHHmm>.dat.gz`, written once and renamed into place. Grids are immutable except a frame's offset-0 grid younger than 20 min, which is revalidated on the next load (`If-None-Match` with the stored ETag; a 304 keeps the file). Pruning keeps the newest − (168 h + 6 h + 1 h) span. Worst case on disk: 168 h at a 6 h span ≈ 252 grids ≈ 4–5 MB gzipped (33 MB raw), so store gzip (`gzip.encode`, `dart:io`).
- **Frame cache:** `<appCache>/rain_accum_frames_v1/<W>h/<yyyyMMddHHmmss>.webp`, the same key format as the radar. A rendered frame is re-rendered only when one of its pieces changed (a revalidation returned 200).
- **Isolate processing (one `Isolate.run` per frame, `radarProcessWorkers` = 2):** parse the k CSR texts and check the header (`441,561`, `linearTransform(0.2500,0.0000)`, `ndv`/`rowPtr` lengths); fail loudly on a mismatch, naming the URL. Then sum into an `Int32List` of raw units, map to the colour scale (0 = transparent), reproject rows to Web Mercator with the existing `mercatorRowMap(srcHeight: 561, south: 20.0, north: 27.0)`, and encode with `encodeRadarWebp`. Output: `RadarFrame` (file + bounds lon 118–123.5 / lat 20–27 + 441 × Mercator height). `significantDbz` is null for this layer.
- **Bounds note:** the open-data grid is TWD67 (offset ≈ 0.008°, ≈ 1 cell), as in history-hourly.md. Same treatment as the existing forecast grid.
- **Web build:** QPEplus sends no CORS header, so the browser cannot fetch it. The layer is unreachable on web. Proof: the missing `Access-Control-Allow-Origin` header (history-hourly.md). Per the no-platform-divergence policy, the user decides whether web shows an error state or hides the card.

Generalising the repository: today `RadarFrameRepository._fetch` downloads one PNG per `RadarFrameRef` and calls `process(png, geometry)`. Change it so a source supplies its own "obtain the processed bytes for this frame" step. The radar step is download + `processRadarFrame`; the accumulation step is pieces from the piece cache + the render isolate. Ordering, pools, cancellation, slot publishing, frame-cache pruning and the `RadarLoop` stream then stay a single module.

## 7. Files and work packages (disjoint ownership)

| WP | goal | owns (create / change) | depends on |
|---|---|---|---|
| WP1 grid core (pure Dart) | CSR parse + checks, piece decomposition, URL builder, sum, colour scale per window; unit test against the real summed frame (3 × 1h = 3h and 4h = 3h + 1h at 2026-11-15 10:50Z, gzipped fixtures of about 15 KB) | create `lib/data/rain_accum/accum_grid.dart`, `lib/data/rain_accum/accum_pieces.dart`, `test/data/rain_accum/accum_grid_test.dart`, `test/fixtures/rain_accum/*.dat.gz` | — |
| WP2 pipeline generalisation + accumulation source | per-source frame step in the repository; accumulation source (deterministic list, piece cache with ETag revalidation, render isolate, Mercator, WebP) | change `lib/data/radar/radar_frame_repository.dart`, `lib/data/radar/radar_source.dart`; create `lib/data/rain_accum/accum_source.dart` | WP1 API; **serialise with the other session that is editing radar files** |
| WP3 settings + providers | `RadarGroup.rainfall`; `RainAccumWindow` setting; accumulation source/loop providers | change `lib/features/radar/radar_playback.dart`; create `lib/features/hazard/rainfall/accum_provider.dart` | WP2 interface (WP3 can start in parallel against the agreed signature) |
| WP4 UI | 累積雨量 card (window chips + map overlay + reused `PlaybackCard`), four-card order, tabs removed | change `lib/features/hazard/rainfall_screen.dart`; create `lib/features/hazard/rainfall/accum_card.dart`; change `lib/features/hazard/rainfall/observation_view.dart` / `forecast_view.dart` only as the card order needs | design-3 sign-off, WP3 |

WP1 and WP3 can run in parallel. WP2 follows WP1, and WP4 comes last. `flutter analyze` and the test suite are the gate for each WP.

## 8. Uncertainties

1. The typhoon-archive mismatch between 1 h and multi-hour grids (§2) is not explained. Whether the same drift appears live within the first hours of a heavy-rain event is unverified; the current week was exact. Strategy A avoids depending on it.
2. TLS was verified only with Dart on macOS. The Android, iOS and Windows trust stores for the TWCA chain are untested; check them on the first device run.
3. The latency figures come from this host only. Mobile networks will be slower, and 252 requests (168 h × 6 h span) is the case to watch (fallback: strategy D, which needs a user decision).
4. Which colour scale goes with which window (1 h / 24 h / 72 h scales exist) is a design decision.
5. QPEplus is an undocumented internal endpoint; the paths could change without notice.
