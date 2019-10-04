// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:cruzawl/eth.dart';
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/test.dart';

void main() {
  EthereumTester(group, test, expect).run();
  //EthereumWalletTester(group, test, expect).run();

  test('ETH currency', () {
    Currency currency = eth;
    expect(ETH.weiPerEth, 1000000000000000000);
    expect(EthereumPublicKey.size, 64);
    expect(EthereumPrivateKey.size, 32);
    //expect(EthereumSignature.size, 64);
    expect(EthereumChainCode.size, 32);
    expect(EthereumTransactionId.size, 32);
    expect(EthereumBlockId.size, 32);

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
