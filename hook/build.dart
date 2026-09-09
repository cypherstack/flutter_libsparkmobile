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
    // The hook configuration does not identify the installed SDK or Xcode build,
    // while the Apple CMake toolchain caches their details as INTERNAL values.
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
  final sdkPath = await _appleToolOutput('xcrun', [
    '--sdk',
    sdk,
    '--show-sdk-path',
  ]);
  defines['CMAKE_OSX_SYSROOT_INT'] = sdkPath;

  final sdkDirectory = Directory(sdkPath);
  final sdkSettings = File.fromUri(
    sdkDirectory.uri.resolve('SDKSettings.json'),
  );
  final sdkVersion = File.fromUri(
    sdkDirectory.uri.resolve('System/Library/CoreServices/SystemVersion.plist'),
  );
  final developerDirectory = Directory(
    await _appleToolOutput('xcode-select', ['--print-path']),
  );
  final xcodeVersion = File.fromUri(
    developerDirectory.parent.uri.resolve('version.plist'),
  );
  final metadataFiles = [
    sdkSettings,
    // Custom SDKs may omit SystemVersion.plist; standalone Command Line Tools
    // have no Xcode app version.plist.
    if (await sdkVersion.exists()) sdkVersion,
    if (await xcodeVersion.exists()) xcodeVersion,
  ];

  // Flutter's outer build cache treats dependencies as files, so a directory
  // dependency would make every build dirty. Track and hash metadata files to
  // detect SDK and Xcode updates in place, including changes in build numbers.
  final cacheIdentity = <String>[sdkPath, developerDirectory.path];
  for (final file in metadataFiles) {
    final bytes = await file.readAsBytes();
    output.dependencies.add(file.uri);
    cacheIdentity.addAll([file.path, sha256.convert(bytes).toString()]);
  }

  return (
    defines: defines,
    appleSdkCacheKey: sha256
        .convert(utf8.encode(jsonEncode(cacheIdentity)))
        .toString(),
  );
}

Future<String> _appleToolOutput(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr as String,
      result.exitCode,
    );
  }
  return (result.stdout as String).trim();
}
