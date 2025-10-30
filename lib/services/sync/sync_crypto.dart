import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class SyncCrypto {
  SyncCrypto._();

  static final _algorithm = Xchacha20.poly1305Aead();

  static Future<Uint8List> encrypt({
    required Uint8List secret,
    required Uint8List nonce,
    required List<int> plaintext,
  }) async {
    final secretKey = SecretKey(secret);
    final result = await _algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return Uint8List.fromList(result.cipherText + result.mac.bytes);
  }

  static Future<Uint8List> decrypt({
    required Uint8List secret,
    required Uint8List nonce,
    required List<int> cipherText,
  }) async {
    final macLength = _algorithm.macAlgorithm.macLength;
    if (cipherText.length < macLength) {
      throw StateError('invalid ciphertext');
    }
    final payload = cipherText.sublist(0, cipherText.length - macLength);
    final mac = Mac(cipherText.sublist(cipherText.length - macLength));
    final box = SecretBox(payload, nonce: nonce, mac: mac);
    final secretKey = SecretKey(secret);
    final plain = await _algorithm.decrypt(box, secretKey: secretKey);
    return Uint8List.fromList(plain);
  }
}
