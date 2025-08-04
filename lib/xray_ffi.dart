import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final DynamicLibrary _lib = () {
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  throw UnsupportedError('Unsupported platform');
}();

final Pointer<Utf8> Function(Pointer<Utf8>) _startXray = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('StartXray')
    .asFunction();

final Pointer<Utf8> Function() _stopXray = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function()>>('StopXray')
    .asFunction();

class XrayFFI {
  static String start(String jsonConfig) {
    final configPtr = jsonConfig.toNativeUtf8();
    final resultPtr = _startXray(configPtr);
    final result = resultPtr.toDartString();
    malloc.free(configPtr);
    return result;
  }

  static String stop() {
    final resultPtr = _stopXray();
    return resultPtr.toDartString();
  }
}
