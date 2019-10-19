// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:ethereum_util/src/signature.dart' as Signature;
import "package:pointycastle/src/utils.dart";

import 'package:cruzawl/btc.dart' hide genesisBlockJson;
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart' as cruz_impl show genesisBlockJson;
import 'package:cruzawl/cruz.dart' hide genesisBlockJson;
import 'package:cruzawl/eth.dart' hide genesisBlockJson;
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

/// Runs bitcoin test vectors and unit tests
class BitcoinTester extends TestRunner {
  BitcoinTester(TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  void run() {
    test('Bitcoin address test', () {
      /// https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
      BitcoinAddress addr = BitcoinAddress.fromPrivateKey(BitcoinPrivateKey(
          Uint8List.fromList(hex.decode(
              '18e14a7b6a307f426a94f8114701e7c8e774e7f9a47e2c2035db29a206321725'))));
      expect(addr.publicKey.toJson(),
          '0250863ad64a87ae8a2fe83c1af1a8403cb53f53e486d8511dad8a04887e5b2352');
      expect(
          addr.identifier.toJson(), 'f54a5851e9372b87810a8e60cdd2e7cfd80b6e31');
      expect(hex.encode(addr.publicAddress.data),
          '00f54a5851e9372b87810a8e60cdd2e7cfd80b6e31c7f18fe8');
      expect(addr.publicAddress.toJson(), '1PMycacnJaSqwwJqjawXBErnLsZ7RkXUAs');
    });

    test('Bitcoin genesis test', () {
      BitcoinBlock genesis = btc.genesisBlock();
      BitcoinBlockId genesisId = genesis.id();
      expect(genesisId.toJson(),
          '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f');
      expect(genesis.header.bits, 0x1d00ffff);
      expect(genesis.header.target.toJson(),
          '00000000ffff0000000000000000000000000000000000000000000000000000');
      expect(genesisId.toBigInt() <= genesis.header.target.toBigInt(), true);
      expect(genesis.header.hashRoot.toJson(),
          '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b');
      expect(
          genesis.computeHashRoot().toJson(), genesis.header.hashRoot.toJson());
      expect(genesis.header.transactionCount, 1);
      expect(genesis.transactions.length, 1);
      expect(genesis.transactions[0].inputs.length, 1);
      expect(genesis.transactions[0].outputs.length, 1);
      expect(genesis.transactions[0].inputs[0].isCoinbase, true);
      expect(genesis.transactions[0].inputs[0].fromText, 'coinbase');
      expect(genesis.transactions[0].outputs[0].toText,
          '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');
      expect(genesis.transactions[0].outputs[0].value, btc.parse('50'));
      expect(genesis.transactions[0].fee, 0);
    });
  }
}

/// Runs BTC wallet test vectors and unit tests
class BitcoinWalletTester extends TestRunner {
  BitcoinWalletTester(
      TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  /// Reference: https://en.bitcoin.it/wiki/BIP_0032_TestVectors
  void run() {
    group('BIP 0032 TestVector 1', () {
      Seed seed =
          Seed.anyLength(hex.decode('000102030405060708090a0b0c0d0e0f'));
      Wallet wallet = Wallet.fromSeed(
          null, null, null, 'BIP32TestVector1', btc.createNetwork(), seed);
      BitcoinAddress addr1, addr2;

      test("BTC wallet", () {
        expect(wallet.bip44Path(13, 0), "m/44'/0'/0'/0/13'");
      });

      test("m", () {
        addr1 = wallet.deriveAddressWithPath("m");
        expect(addr1.publicKey.toJson(),
            '0339a36013301597daef41fbe593a02cc513d0b55527ec2df1050e2e8ff49c85c2');
        expect(hex.encode(addr1.privateKey.data),
            'e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35');
        expect(addr1.chainCode.toJson(),
            '873dff81c02f525623fd1fe5167eac3a55a049de3d314bb42ee227ffed37d508');
        expect(addr1.privateKey.toJson(),
            'L52XzL2cMkHxqxBXRyEpnPQZGUs3uKiL3R11XbAdHigRzDozKZeW');
        expect(
            addr1.publicAddress.toJson(), '15mKKb2eos1hWa6tisdPwwDC1a5J1y9nma');
        expect(addr1.identifier.toJson(),
            '3442193e1bb70916e914552172cd4e2dbc9df811');
        expect(addr1.extendedPublicKeyJson(),
            'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8');
        expect(addr1.extendedPrivateKeyJson(),
            'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi');
        expect(addr1.parentFingerprint, 0);
        expect(addr1.verify(), true);

        addr2 = BitcoinAddress.fromPrivateKey(
            BitcoinPrivateKey.fromJson(addr1.privateKey.toJson()));
        expect(addr2.publicKey.toJson(), addr1.publicKey.toJson());
        expect(addr2.privateKey.toJson(), addr1.privateKey.toJson());
        expect(addr2.verify(), true);
      });

      test("m/0'", () {
        addr1 = wallet.deriveAddressWithPath("m/0'");
        expect(addr1.publicKey.toJson(),
            '035a784662a4a20a65bf6aab9ae98a6c068a81c52e4b032c0fb5400c706cfccc56');
        expect(hex.encode(addr1.privateKey.data),
            'edb2e14f9ee77d26dd93b4ecede8d16ed408ce149b6cd80b0715a2d911a0afea');
        expect(addr1.chainCode.toJson(),
            '47fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141');
        expect(addr1.privateKey.toJson(),
            'L5BmPijJjrKbiUfG4zbiFKNqkvuJ8usooJmzuD7Z8dkRoTThYnAT');
        expect(addr1.identifier.toJson(),
            '5c1bd648ed23aa5fd50ba52b2457c11e9e80a6a7');
        expect(
            addr1.publicAddress.toJson(), '19Q2WoS5hSS6T8GjhK8KZLMgmWaq4neXrh');
        expect(addr1.extendedPrivateKeyJson(),
            'xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7');
        expect(addr1.extendedPublicKeyJson(),
            'xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw');

        /// https://github.com/satoshilabs/slips/blob/master/slip-0010.md
        expect(addr1.parentFingerprint, 0x3442193e);

        addr2 =
            BitcoinAddress.fromExtendedKeyJson(addr1.extendedPrivateKeyJson());
        expect(addr2.publicKey.toJson(), addr1.publicKey.toJson());
        expect(addr2.privateKey.toJson(), addr1.privateKey.toJson());
        expect(addr2.extendedPublicKeyJson(), addr1.extendedPublicKeyJson());
        expect(addr2.extendedPrivateKeyJson(), addr1.extendedPrivateKeyJson());
        expect(addr2.verify(), true);
      });

      test("m/0'/1/2'/2/1000000000", () {
        addr1 = wallet.deriveAddressWithPath("m/0'/1/2'/2/1000000000");
        expect(addr1.publicKey.toJson(),
            '022a471424da5e657499d1ff51cb43c47481a03b1e77f951fe64cec9f5a48f7011');
        expect(hex.encode(addr1.privateKey.data),
            '471b76e389e528d6de6d816857e012c5455051cad6660850e58372a6c3e6e7c8');
        expect(addr1.chainCode.toJson(),
            'c783e67b921d2beb8f6b389cc646d7263b4145701dadd2161548a8b078e65e9e');
        expect(addr1.privateKey.toJson(),
            'Kybw8izYevo5xMh1TK7aUr7jHFCxXS1zv8p3oqFz3o2zFbhRXHYs');
        expect(addr1.identifier.toJson(),
            'd69aa102255fed74378278c7812701ea641fdf32');
        expect(
            addr1.publicAddress.toJson(), '1LZiqrop2HGR4qrH1ULZPyBpU6AUP49Uam');
        expect(addr1.extendedPrivateKeyJson(),
            'xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76');
        expect(addr1.extendedPublicKeyJson(),
            'xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy');
        expect(addr1.parentFingerprint, 0xd880d7d8);
      });
    });
  }
}

/// Runs cruzbit test vectors and unit tests
class CruzTester extends TestRunner {
  CruzTester(TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  void run() {
    group('CRUZ Transaction TestVector1', () {
      /// Create [CruzTransaction] for Test Vector 1.
      /// Reference: https://github.com/cruzbit/cruzbit/blob/master/transaction_test.go#L59
      CruzPublicKey pubKey = CruzPublicKey.fromJson(
          '80tvqyCax0UdXB+TPvAQwre7NxUHhISm/bsEOtbF+yI=');
      CruzPublicKey pubKey2 = CruzPublicKey.fromJson(
          'YkJHRtoQDa1TIKhN7gKCx54bavXouJy4orHwcRntcZY=');
      CruzTransaction tx = CruzTransaction(pubKey, pubKey2,
          50 * CRUZ.cruzbitsPerCruz, 2 * CRUZ.cruzbitsPerCruz, 'for lunch',
          seriesForHeight: 0);
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

    test('CRUZ genesis test', () {
      CruzBlock genesis = cruz.genesisBlock();
      expect(jsonEncode(genesis),
          jsonEncode(jsonDecode(cruz_impl.genesisBlockJson)));
      expect(
          genesis.computeHashRoot().toJson(), genesis.header.hashRoot.toJson());

      CruzBlockId genesisId = genesis.id();
      expect(genesisId.toJson(),
          '00000000e29a7850088d660489b7b9ae2da763bc3bd83324ecc54eee04840adb');
      expect(genesisId.toBigInt() <= genesis.header.target.toBigInt(), true);
    });
  }
}

/// Runs CRUZ wallet test vectors and unit tests
class CruzWalletTester extends TestRunner {
  CruzWalletTester(TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  void run() {
    /// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0010.md#test-vector-2-for-ed25519
    group('SLIP 0010 Test vector 2 for ed25519', () {
      Wallet wallet = Wallet.fromSeed(
          null,
          null,
          null,
          'SLIP10TestVector2',
          cruz.createNetwork(),
          Seed(hex.decode(
              'fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542')));
      CruzAddress addr1, addr2;

      test("CRUZ wallet", () {
        expect(wallet.bip44Path(13, 831), "m/44'/831'/0'/0'/13'");
      });

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
            seriesForHeight: 0);
        tx.sign(addr1.privateKey);
        expect(tx.verify(), true);
        tx.sign(addr2.privateKey);
        expect(tx.verify(), false);
      });
    });
  }
}

/// Runs ethereum test vectors and unit tests
class EthereumTester extends TestRunner {
  EthereumTester(TestCallback group, TestCallback test, ExpectCallback expect)
      : super(group, test, expect);

  void run() {
    test('Ethereum address test', () {
      /// https://medium.com/@codetractio/inside-an-ethereum-transaction-fa94ffca912f
      EthereumAddress addr = EthereumAddress.fromPrivateKey(
          EthereumPrivateKey.fromJson(
              'c0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0dec0de'));
      expect(addr.publicKey.toJson(),
          '0x4643bb6b393ac20a6175c713175734a72517c63d6f73a3ca90a15356f2e967da03d16431441c61ac69aeabb7937d333829d9da50431ff6af38536aa262497b27');
      expect(addr.publicAddress.toJson(),
          '0x53ae893e4b22d707943299a8d0c844df0e3d5557');

      /// https://bitcoin.stackexchange.com/a/42097
      addr = EthereumAddress.fromPrivateKey(EthereumPrivateKey.fromJson(
          'b205a1e03ddf50247d8483435cd91f9c732bad281ad420061ab4310c33166276'));
      expect(addr.publicKey.toJson(),
          '0x6cb84859e85b1d9a27e060fdede38bb818c93850fb6e42d9c7e4bd879f8b9153fd94ed48e1f63312dce58f4d778ff45a2e5abb08a39c1bc0241139f5e54de7df');
      expect(addr.publicAddress.toJson(),
          '0xafdefc1937ae294c3bd55386a8b9775539d81653');

      /// https://ethereum.stackexchange.com/q/6520
      addr = EthereumAddress.fromPrivateKey(EthereumPrivateKey.fromJson(
          '0xe9873d79c6d87dc0fb6a5778633389f4453213303da61f20bd67fc233aa33262'));
      expect(addr.publicAddress.toJson(),
          '0x60751ab56d58781069b1c73064ad580dade1f469');
    });

    test('Ethereum genesis test', () {
      EthereumBlock genesis = eth.genesisBlock();
      EthereumBlockId genesisId = genesis.header.hash;
      expect(genesisId.toJson(),
          '0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3');
      expect(genesis.header.miner.toJson(),
          '0x0000000000000000000000000000000000000000');
      expect(genesis.header.size, 0x21c);
      expect(genesis.header.difficulty.toInt(), 0x400000000);
      expect(genesis.header.target.toJson(),
          '0x0000000040000000000000000000000000000000000000000000000000000000');
      expect(genesis.header.hashRoot.toJson(),
          '0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421');
      /*expect(
          genesis.computeHashRoot().toJson(), genesis.header.hashRoot.toJson());*/
      expect(genesis.header.transactionCount, null);
      expect(genesis.transactions.length, 0);
      expect(genesis.id().toJson(), genesisId.toJson());
      expect(
          EthereumBlock.fromJson(jsonDecode(jsonEncode(genesis))).id().toJson(),
          genesisId.toJson());
    });

    test('Ethereum transaction test', () {
      /// https://goethereumbook.org/transaction-raw-send/
      String txnHex =
          'f86d8202b28477359400825208944592d8f8d7b001e72cb26a73e4fa1806a51ac79d880de0b6b3a7640000802ca05924bde7ef10aa88db9c66dd4f5fb16b46dff2319b9968be983118b57bb50562a001b24b31010004f13d9a26b320845257a6cfc2bf819a3d55e3fc86263c5f0772';
      EthereumTransaction txn = EthereumTransaction.fromRlp(hex.decode(txnHex));
      expect(txn.from.toJson(), '0x96216849c49358b10257cb55b28ea603c874b05e');
      expect(txn.to.toJson(), '0x4592d8f8d7b001e72cb26a73e4fa1806a51ac79d');
      expect(txn.id().toJson(),
          '0xc429e5f128387d224ba8bed6885e86525e14bfdc2eb24b5e9c3351a1176fd81f');
      expect(txn.nonce, 690);
      expect(txn.gas, 21000);
      expect(txn.gasPrice, eth.parse('0.000000002'));
      expect(txn.value, eth.parse('1'));
      expect(txn.input.length, 0);
      expect(txn.sigR.length, 32);
      expect(txn.sigS.length, 32);
      expect(txn.verify(), true);
      expect(EthereumAddressHash.compute(txn.recoverSenderPublicKey()).toJson(),
          txn.from.toJson());

      EthereumAddress address = EthereumAddress.generateRandom();
      expect(address.publicAddress.data,
          Signature.publicKeyToAddress(address.publicKey.data));
      expect(address.publicAddress.data,
          Signature.privateKeyToAddress(address.privateKey.data));
      expect(address.publicKey.data,
          Signature.privateKeyToPublicKey(address.privateKey.data));

      txn.sign(address.privateKey);
      expect(txn.verify(), false);
      txn.from = address.publicAddress;
      expect(txn.verify(), true);
      expect(txn.recoverSenderPublicKey().toJson(), address.publicKey.toJson());

      EthereumTransaction txn2 = EthereumTransaction.fromRlp(txn.toRlp());
      expect(txn2.from.toJson(), address.publicAddress.toJson());
      expect(txn2.verify(), true);
    });
  }
}
