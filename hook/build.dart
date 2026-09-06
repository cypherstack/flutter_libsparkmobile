import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

const _assetName = 'src/flutter_libsparkmobile_bindings_generated.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final sourceDir = input.packageRoot.resolve('src/');
    final (:defines, :appleSdkCacheKey) = await _cmakeConfiguration(
      input,
      output,
    );
    // The hook configuration does not identify the installed Xcode SDK, while
    // the Apple CMake toolchain caches SDK details as INTERNAL values.
    final buildDir = input.outputDirectory.resolve(
      appleSdkCacheKey == null ? 'cmake/' : 'cmake-$appleSdkCacheKey/',
    );
    final builder = CMakeBuilder.create(
      name: input.packageName,
      sourceDir: sourceDir,
      outDir: buildDir,
      defines: defines,
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

Future<({Map<String, String> defines, String? appleSdkCacheKey})>
_cmakeConfiguration(BuildInput input, BuildOutputBuilder output) async {
  final os = input.config.code.targetOS;
  final defines = {'BUILD_FOR_SYSTEM_NAME': os.name};
  if (os != OS.iOS && os != OS.macOS) {
    return (defines: defines, appleSdkCacheKey: null);
  }

  final sdk = os == OS.macOS
      ? 'macosx'
      : input.config.code.iOS.targetSdk == IOSSdk.iPhoneSimulator
      ? 'iphonesimulator'
      : 'iphoneos';
  final arguments = ['--sdk', sdk, '--show-sdk-path'];
  final result = await Process.run('xcrun', arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      'xcrun',
      arguments,
      result.stderr as String,
      result.exitCode,
    );
  }
  final sdkPath = (result.stdout as String).trim();
  defines['CMAKE_OSX_SYSROOT_INT'] = sdkPath;

  final sdkDirectory = Directory(sdkPath);
  final sdkSettings = File.fromUri(
    sdkDirectory.uri.resolve('SDKSettings.json'),
  );
  // Flutter includes xcrun's compiler paths in the hook configuration, which
  // handles switching Xcode. These dependencies handle an in-place SDK update.
  output.dependencies.addAll([sdkSettings.uri, sdkDirectory.parent.uri]);
  final sdkSettingsBytes = await sdkSettings.readAsBytes();

  return (
    defines: defines,
    appleSdkCacheKey: sha256.convert([
      ...utf8.encode(sdkPath),
      0,
      ...sdkSettingsBytes,
    ]).toString(),
  );
}
