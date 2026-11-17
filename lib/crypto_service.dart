import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class LinkCryptoException implements Exception {
  const LinkCryptoException(this.message);

  final String message;

  @override
  String toString() => 'LinkCryptoException: $message';
}

/// Password-based link encryption.
///
/// Key derivation: PBKDF2-HMAC-SHA256 (random 16-byte salt).
/// Encryption:     AES-256-GCM (random 12-byte nonce).
///
/// Token = `LL1.` + base64url(bytes) without padding, where bytes are:
///   [0]       format version (1)
///   [1..4]    PBKDF2 iterations, uint32 big-endian
///   [5..20]   salt (16 bytes)
///   [21..32]  AES-GCM nonce (12 bytes)
///   [33..]    ciphertext followed by the 16-byte GCM tag
///
/// The first 21 bytes (version, iterations, salt) are authenticated as AAD,
/// so any change to them makes decryption fail.
class LinkCrypto {
  LinkCrypto({this.iterations = defaultIterations, Random? random})
      : assert(iterations > 0 && iterations <= _maxIterations),
        _random = random ?? Random.secure();

  static const String prefix = 'LL1.';
  static const int defaultIterations = 200000;

  static const int _version = 1;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _headerLength = 1 + 4 + _saltLength; // 21
  // Upper bound so a crafted token can't make the app spin forever.
  static const int _maxIterations = 2000000;

  final int iterations;
  final Random _random;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<String> encrypt(String link, String password) async {
    final text = link.trim();
    if (text.isEmpty) {
      throw const LinkCryptoException('اكتب الرابط الأول');
    }
    if (password.isEmpty) {
      throw const LinkCryptoException('اكتب كلمة السر');
    }

    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final header = _buildHeader(iterations, salt);
    final key = await _deriveKey(password, salt, iterations);

    final box = await _cipher.encrypt(
      utf8.encode(text),
      secretKey: key,
      nonce: nonce,
      aad: header,
    );

    // box.concatenation() = nonce + ciphertext + tag
    final out = BytesBuilder(copy: false)
      ..add(header)
      ..add(box.concatenation());
    return prefix + base64Url.encode(out.toBytes()).replaceAll('=', '');
  }

  Future<String> decrypt(String token, String password) async {
    final compact = token.replaceAll(RegExp(r'\s+'), '');
    if (!compact.startsWith(prefix)) {
      throw const LinkCryptoException('ده مش نص مشفّر بالتطبيق ده');
    }
    if (password.isEmpty) {
      throw const LinkCryptoException('اكتب كلمة السر');
    }

    Uint8List data;
    try {
      data = base64Url.decode(
        base64Url.normalize(compact.substring(prefix.length)),
      );
    } on FormatException {
      throw const LinkCryptoException('النص المشفّر ناقص أو متعدّل');
    }

    if (data.length < _headerLength + _nonceLength + _macLength) {
      throw const LinkCryptoException('النص المشفّر ناقص أو متعدّل');
    }
    if (data[0] != _version) {
      throw const LinkCryptoException('إصدار التشفير ده مش مدعوم');
    }

    final storedIterations = ByteData.sublistView(data).getUint32(1, Endian.big);
    if (storedIterations < 1 || storedIterations > _maxIterations) {
      throw const LinkCryptoException('النص المشفّر ناقص أو متعدّل');
    }

    final header = Uint8List.sublistView(data, 0, _headerLength);
    final salt = Uint8List.sublistView(data, 5, _headerLength);
    final body = Uint8List.sublistView(data, _headerLength);

    final key = await _deriveKey(password, salt, storedIterations);

    try {
      final box = SecretBox.fromConcatenation(
        body,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      final clear = await _cipher.decrypt(box, secretKey: key, aad: header);
      return utf8.decode(clear);
    } catch (_) {
      throw const LinkCryptoException('كلمة السر غلط أو النص المشفّر اتعدّل');
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  static Uint8List _buildHeader(int iterations, List<int> salt) {
    final header = Uint8List(_headerLength);
    header[0] = _version;
    ByteData.sublistView(header).setUint32(1, iterations, Endian.big);
    header.setRange(5, _headerLength, salt);
    return header;
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
        List<int>.generate(length, (_) => _random.nextInt(256)),
      );
}
