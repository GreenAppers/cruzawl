import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:cruzawl/cruz.dart';

void main() {
  group('TestVector1', () {
    // create transaction for Test Vector 1
    CruzPublicKey pubKey =
        CruzPublicKey.fromJson('80tvqyCax0UdXB+TPvAQwre7NxUHhISm/bsEOtbF+yI=');
    CruzPublicKey pubKey2 =
        CruzPublicKey.fromJson('YkJHRtoQDa1TIKhN7gKCx54bavXouJy4orHwcRntcZY=');
    CruzTransaction tx = CruzTransaction(pubKey, pubKey2,
        50 * CRUZ.cruzbitsPerCruz, 2 * CRUZ.cruzbitsPerCruz, 'for lunch', height: 0);
    tx.time = 1558565474;
    tx.nonce = 2019727887;

    test('JSON matches test vector', () {
      expect(jsonEncode(tx.unsignedJson()),
          '{"time":1558565474,"nonce":2019727887,"from":"80tvqyCax0UdXB+TPvAQwre7NxUHhISm/bsEOtbF+yI=","to":"YkJHRtoQDa1TIKhN7gKCx54bavXouJy4orHwcRntcZY=","amount":5000000000,"fee":200000000,"memo":"for lunch","series":1}');
    });

    test('ID matches test vector', () {
      expect(tx.id().toJson(),
          'fc04870db147eb31823ce7c68ef366a7e94c2a719398322d746ddfd0f5c98776');
    });

    test('verify signature from test vector', () {
      expect(tx.verify(), false);
      tx.signature = CruzSignature.fromJson(
          'Fgb3q77evL5jZIXHMrpZ+wBOs2HZx07WYehi6EpHSlvnRv4wPvrP2sTTzAAmdvJZlkLrHXw1ensjXBiDosucCw==');
      expect(tx.verify(), true);
    });

    test('re-sign the transaction with private key from test vector', () {
      CruzPrivateKey privKey = CruzPrivateKey.fromJson(
          'EBQtXb3/Ht6KFh8/+Lxk9aDv2Zrag5G8r+dhElbCe07zS2+rIJrHRR1cH5M+8BDCt7s3FQeEhKb9uwQ61sX7Ig==');
      tx.sign(privKey);
      expect(tx.verify(), true);
    });

    test('re-sign the transaction with the wrong private key', () {
      CruzAddress address = CruzAddress.generateRandom();
      tx.sign(address.privateKey);
      expect(tx.verify(), false);
    });
  });

  test('Test Genesis', () {
    CruzBlock genesis = CruzBlock.fromJson(jsonDecode(genesisBlockJson));
    expect(jsonEncode(genesis), jsonEncode(jsonDecode(genesisBlockJson)));
    expect(genesis.id().toJson(),
        '00000000e29a7850088d660489b7b9ae2da763bc3bd83324ecc54eee04840adb');
  });
}
