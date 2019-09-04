// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:convert/convert.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/wallet.dart';

typedef TestCallback = void Function(String, VoidCallback);
typedef ExpectCallback = void Function(dynamic, dynamic);

/// Harness for running [package:test] unit tests in-app.
///
/// It's always a good practice to run unit tests with objective test vectors (in-app)
/// before doing any sensitive cryptography.
abstract class TestRunner {
  TestCallback group, test;
  ExpectCallback expect;
  TestRunner(this.group, this.test, this.expect);

  void run();
}

/// Runs cruzbit test vectors and unit tests
class CruzTester extends TestRunner {
  CruzTester(TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  void run() {
    group('TestVector1', () {
      /// Create [CruzTransaction] for Test Vector 1.
      /// Reference: https://github.com/cruzbit/cruzbit/blob/master/transaction_test.go#L59
      CruzPublicKey pubKey = CruzPublicKey.fromJson(
          '80tvqyCax0UdXB+TPvAQwre7NxUHhISm/bsEOtbF+yI=');
      CruzPublicKey pubKey2 = CruzPublicKey.fromJson(
          'YkJHRtoQDa1TIKhN7gKCx54bavXouJy4orHwcRntcZY=');
      CruzTransaction tx = CruzTransaction(pubKey, pubKey2,
          50 * CRUZ.cruzbitsPerCruz, 2 * CRUZ.cruzbitsPerCruz, 'for lunch',
          height: 0);
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
      expect(genesis.computeHashListRoot().toJson(),
          genesis.header.hashListRoot.toJson());

      CruzBlockId genesisId = genesis.id();
      expect(genesisId.toJson(),
          '00000000e29a7850088d660489b7b9ae2da763bc3bd83324ecc54eee04840adb');
      expect(genesisId.toBigInt() <= genesis.header.target.toBigInt(), true);
    });
  }
}

/// Runs wallet test vectors and unit tests
class WalletTester extends TestRunner {
  WalletTester(TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  void run() {
    /// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0010.md#test-vector-2-for-ed25519
    group('SLIP 0010 Test vector 2 for ed25519', () {
      Wallet wallet = Wallet.fromSeed(
          null,
          null,
          null,
          'TestVector2',
          cruz.createNetwork(),
          Seed(hex.decode(
              'fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542')));
      CruzAddress addr1, addr2;

      test("m/0'", () {
        addr1 = wallet.deriveAddressWithPath("m/0'");
        expect(hex.encode(addr1.privateKey.data.buffer.asUint8List(0, 32)),
            '1559eb2bbec5790b0c65d8693e4d0875b1747f4970ae8b650486ed7470845635');
        expect(hex.encode(addr1.publicKey.data),
            '86fab68dcb57aa196c77c5f264f215a112c22a912c10d123b0d03c3c28ef1037');
        expect(hex.encode(addr1.chainCode.data),
            '0b78a3226f915c082bf118f83618a618ab6dec793752624cbeb622acb562862d');
      });

      test("m/0'/2147483647'/1'/2147483646'/2'", () {
        addr2 =
            wallet.deriveAddressWithPath("m/0'/2147483647'/1'/2147483646'/2'");
        expect(hex.encode(addr2.privateKey.data.buffer.asUint8List(0, 32)),
            '551d333177df541ad876a60ea71f00447931c0a9da16f227c11ea080d7391b8d');
        expect(hex.encode(addr2.publicKey.data),
            '47150c75db263559a70d5778bf36abbab30fb061ad69f69ece61a72b0cfa4fc0');
        expect(hex.encode(addr2.chainCode.data),
            '5d70af781f3a37b829f0d060924d5e960bdc02e85423494afc0b1a41bbe196d4');
      });

      test('transaction', () {
        CruzTransaction tx = CruzTransaction(addr1.publicKey, addr2.publicKey,
            50 * CRUZ.cruzbitsPerCruz, 0, 'for lunch',
            height: 0);
        tx.sign(addr1.privateKey);
        expect(tx.verify(), true);
        tx.sign(addr2.privateKey);
        expect(tx.verify(), false);
      });
    });
  }
}
