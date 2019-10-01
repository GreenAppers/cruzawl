// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:test/test.dart';

import 'package:cruzawl/btc.dart';
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/test.dart';

void main() {
  BitcoinTester(group, test, expect).run();
  BitcoinWalletTester(group, test, expect).run();

  test('BTC currency', () {
    Currency currency = btc;
    expect(BTC.satoshisPerBitcoin, 100000000);
    expect(BTC.initialCoinbaseReward, 50);
    expect(BTC.blocksUntilRewardHalving, 210000);
    expect(BitcoinPublicKey.size, 33);
    expect(BitcoinPrivateKey.size, 32);
    //expect(BitcoinSignature.size, 64);
    expect(BitcoinChainCode.size, 32);
    expect(BitcoinTransactionId.size, 32);
    expect(BitcoinBlockId.size, 32);

    /// https://en.bitcoin.it/wiki/Protocol_documentation
    expect(
        hex.encode(BitcoinAddressIdentifier.hash(
            Uint8List.fromList('hello'.codeUnits))),
        'b6a9c8c230722b7c748331a8b450f05566dc7d0f');

    expect(
        currency
            .fromBlockIdJson(
                '00000000000555de1d28a55fd2d5d2069c61fd46c4618cfea16c5adf6d902f4d')
            .toJson(),
        currency
            .fromBlockIdJson(
                '555de1d28a55fd2d5d2069c61fd46c4618cfea16c5adf6d902f4d', true)
            .toJson());
    expect(
        currency
            .fromTransactionIdJson(
                '0000cb989226cc52493ca92754acda383e0b483ac433e9216f53f13be3570459',
                true)
            .toJson(),
        currency
            .fromTransactionIdJson(
                'cb989226cc52493ca92754acda383e0b483ac433e9216f53f13be3570459',
                true)
            .toJson());

    /*expect(currency.nullAddress.toJson(),
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
    expect(currency.suggestedFee(null), '0.01');
    expect(currency.parse(currency.suggestedFee(null)), 1000000);
    expect(currency.supply(210033), 10500825);*/
  });
}
