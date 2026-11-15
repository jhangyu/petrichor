// Builds libwebp + the radar shim by running tools/build_libwebp.py and
// declares the resulting shared library as a code asset. All compile logic
// lives in the Python script.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

// Asset id `package:cwb_flutter/radar_webp`, bound by the @DefaultAsset in
// lib/data/radar/radar_webp.dart.
const _assetName = 'radar_webp';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final os = code.targetOS;
    final script = input.packageRoot.resolve('tools/build_libwebp.py');
    final cc = code.cCompiler;
    final scriptArgs = [
      script.toFilePath(),
      '--os', os.name,
      '--arch', code.targetArchitecture.name,
      '--out-dir', input.outputDirectory.toFilePath(),
      '--cache-dir', input.outputDirectoryShared.resolve('libwebp/').toFilePath(),
      if (cc != null) ...['--cc', cc.compiler.toFilePath()],
      if (os == OS.macOS) ...['--min-os-version', '${code.macOS.targetVersion}'],
      if (os == OS.iOS) ...[
        '--min-os-version', '${code.iOS.targetVersion}',
        '--ios-sdk', code.iOS.targetSdk.type,
      ],
      if (os == OS.android) ...['--min-os-version', '${code.android.targetNdkApi}'],
      if (os == OS.windows && cc != null) ..._vcvarsArgs(cc),
    ];
    // The hook runs on the build host; Windows installs Python 3 behind the
    // `py` launcher, other hosts as `python3`.
    final (exe, prefix) = Platform.isWindows ? ('py', ['-3']) : ('python3', <String>[]);
    final result = await Process.run(exe, [...prefix, ...scriptArgs]);
    if (result.exitCode != 0) {
      throw StateError(
        'build_libwebp.py failed: expected exit 0, got ${result.exitCode} '
        'for $exe ${[...prefix, ...scriptArgs].join(' ')}\n${result.stdout}${result.stderr}',
      );
    }
    final lines = (result.stdout as String).trim().split('\n');
    final library = File(lines.last.trim());
    if (!library.existsSync()) {
      throw StateError('build_libwebp.py reported ${library.path}, which does not exist');
    }
    output.dependencies.addAll([
      script,
      input.packageRoot.resolve('native/radar_webp/radar_webp.h'),
      input.packageRoot.resolve('native/radar_webp/radar_webp.c'),
      input.packageRoot.resolve('native/radar_webp/libwebp_alloc.h'),
    ]);
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        file: library.absolute.uri,
        linkMode: DynamicLoadingBundled(),
      ),
    );
  });
}

List<String> _vcvarsArgs(CCompilerConfig cc) {
  final prompt = cc.windows.developerCommandPrompt;
  if (prompt == null) {
    throw StateError('Windows build needs the Visual Studio developer prompt script, got none');
  }
  if (prompt.arguments.isNotEmpty) {
    throw StateError('expected no developer prompt arguments, got ${prompt.arguments}');
  }
  return ['--vcvars', prompt.script.toFilePath()];
}
