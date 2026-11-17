import 'package:flutter_test/flutter_test.dart';
import 'package:linklock/crypto_service.dart';

void main() {
  // Few iterations keep the tests fast; the app uses LinkCrypto.defaultIterations.
  final crypto = LinkCrypto(iterations: 1000);
  const password = 'correct horse battery';

  test('round trip returns the original link', () async {
    const link = 'https://example.com/path?a=1&b=two#frag';
    final token = await crypto.encrypt(link, password);

    expect(token.startsWith(LinkCrypto.prefix), isTrue);
    expect(token.contains('example.com'), isFalse);
    expect(await crypto.decrypt(token, password), link);
  });

  test('handles Arabic text and emoji', () async {
    const link = 'https://مثال.com/صفحة?q=تجربة 🔒';
    final token = await crypto.encrypt(link, password);
    expect(await crypto.decrypt(token, password), link);
  });

  test('trims the link before encrypting', () async {
    final token = await crypto.encrypt('  https://a.io  \n', password);
    expect(await crypto.decrypt(token, password), 'https://a.io');
  });

  test('same input gives a different token every time', () async {
    final a = await crypto.encrypt('https://a.io', password);
    final b = await crypto.encrypt('https://a.io', password);
    expect(a, isNot(equals(b)));
  });

  test('wrong password is rejected', () async {
    final token = await crypto.encrypt('https://a.io', password);
    await expectLater(
      crypto.decrypt(token, 'wrong password'),
      throwsA(isA<LinkCryptoException>()),
    );
  });

  test('tampered token is rejected', () async {
    final token = await crypto.encrypt('https://a.io/secret', password);
    final mid = token.length ~/ 2;
    final tampered = token.substring(0, mid) +
        (token[mid] == 'A' ? 'B' : 'A') +
        token.substring(mid + 1);

    await expectLater(
      crypto.decrypt(tampered, password),
      throwsA(isA<LinkCryptoException>()),
    );
  });

  test('token with whitespace and line breaks still decrypts', () async {
    final token = await crypto.encrypt('https://a.io', password);
    final wrapped = '${token.substring(0, 20)}\n ${token.substring(20)} ';
    expect(await crypto.decrypt(wrapped, password), 'https://a.io');
  });

  test('garbage and truncated input are rejected', () async {
    final token = await crypto.encrypt('https://a.io', password);
    for (final bad in ['hello', 'LL1.', 'LL1.@@@@', token.substring(0, 30)]) {
      await expectLater(
        crypto.decrypt(bad, password),
        throwsA(isA<LinkCryptoException>()),
        reason: 'input: $bad',
      );
    }
  });

  test('empty link or password is rejected', () async {
    await expectLater(
      crypto.encrypt('   ', password),
      throwsA(isA<LinkCryptoException>()),
    );
    await expectLater(
      crypto.encrypt('https://a.io', ''),
      throwsA(isA<LinkCryptoException>()),
    );
  });
}
