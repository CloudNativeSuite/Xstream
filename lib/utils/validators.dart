import 'package:flutter/foundation.dart';

/// Throws [ArgumentError] if [value] is empty.
void checkNotEmpty(String value, String name) {
  assert(value.isNotEmpty, '$name is empty: $value');
  if (value.isEmpty) {
    debugPrint('❌ $name is empty: $value');
    throw ArgumentError('$name is empty');
  }
}

/// Throws [ArgumentError] if [value] is null.
void checkNotNull(Object? value, String name) {
  assert(value != null, '$name is null');
  if (value == null) {
    debugPrint('❌ $name is null');
    throw ArgumentError('$name is null');
  }
}
