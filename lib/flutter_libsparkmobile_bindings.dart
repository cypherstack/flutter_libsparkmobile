// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_element, unused_field, return_of_invalid_type, void_checks, annotate_overrides, no_leading_underscores_for_local_identifiers, library_private_types_in_public_api

// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

/// Bindings for sparkmobile.
class SparkMobileBindings {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  SparkMobileBindings(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  SparkMobileBindings.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  ffi.Pointer<ffi.Char> generateSpendKey() {
    return _generateSpendKey();
  }

  late final _generateSpendKeyPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>(
          'generateSpendKey');
  late final _generateSpendKey =
      _generateSpendKeyPtr.asFunction<ffi.Pointer<ffi.Char> Function()>();

  ffi.Pointer<ffi.Char> createSpendKey(
    ffi.Pointer<ffi.Char> r,
  ) {
    return _createSpendKey(
      r,
    );
  }

  late final _createSpendKeyPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ffi.Char>)>>('createSpendKey');
  late final _createSpendKey = _createSpendKeyPtr
      .asFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>();

  ffi.Pointer<ffi.Char> createFullViewKey(
    ffi.Pointer<ffi.Char> spend_key_r,
  ) {
    return _createFullViewKey(
      spend_key_r,
    );
  }

  late final _createFullViewKeyPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ffi.Char>)>>('createFullViewKey');
  late final _createFullViewKey = _createFullViewKeyPtr
      .asFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>();
}