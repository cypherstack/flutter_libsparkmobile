import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

const _assetName = 'src/flutter_libsparkmobile_bindings_generated.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final sourceDir = input.packageRoot.resolve('src/');
    final buildDir = input.outputDirectory.resolve('cmake/');
    final builder = CMakeBuilder.create(
      name: input.packageName,
      sourceDir: sourceDir,
      outDir: buildDir,
      defines: await _cmakeDefines(input),
      targets: [input.packageName],
    );

    await builder.run(input: input, output: output);
    // On Windows search only the Visual Studio config dir: the full build tree
    // holds the extracted Boost sources, whose paths exceed MAX_PATH.
    final searchDir = input.config.code.targetOS == OS.windows
        ? buildDir.resolve('Release/')
        : buildDir;
    final assets = await output.findAndAddCodeAssets(
      input,
      names: {input.packageName: _assetName},
      outDir: searchDir,
    );
    if (assets.length != 1) {
      throw StateError('Expected one ${input.packageName} native library.');
    }

    await for (final entity in Directory.fromUri(
      sourceDir,
    ).list(recursive: true)) {
      if (entity is File) output.dependencies.add(entity.uri);
    }
  });
}

Future<Map<String, String>> _cmakeDefines(BuildInput input) async {
  final os = input.config.code.targetOS;
  final defines = {'BUILD_FOR_SYSTEM_NAME': os.name};
  if (os != OS.iOS && os != OS.macOS) return defines;

  final sdk = os == OS.macOS
      ? 'macosx'
      : input.config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator
      ? 'iphonesimulator'
      : 'iphoneos';
  final result = await Process.run('xcrun', ['--sdk', sdk, '--show-sdk-path']);
  if (result.exitCode != 0) {
    throw ProcessException('xcrun', [
      '--sdk',
      sdk,
      '--show-sdk-path',
    ], result.stderr as String);
  }
  defines['CMAKE_OSX_SYSROOT_INT'] = (result.stdout as String).trim();
  return defines;
}
