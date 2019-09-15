// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/test.dart';

void main() {
  CruzTester(group, test, expect).run();

  test('WebSocket connection to public seeder', () async {
    Completer<void> completer = Completer<void>();
    PeerNetwork network = cruz.createNetwork();
    network.tipChanged = () => completer.complete(null);
    network
        .addPeer(network.createPeerWithSpec(
            PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ',
                ',ignoreBadCert,', debugPrint: (x) {/* print('DEBUG: $x'); */}),
            cruz.genesisBlock().id().toJson()))
        .connect();

    await completer.future;
    BlockHeader block = network.tip;
    print('Found tip height = ${block.height}');
    expect(block.height > 0, true);

    network.shutdown();
  });

  test('LoadingCurrency', () {
    expect(loadingCurrency.ticker, cruz.ticker);
    expect(loadingCurrency.bip44CoinType, 0);
    expect(loadingCurrency.coinbaseMaturity, 0);
    expect(loadingCurrency.nullAddress, null);
    expect(loadingCurrency.createNetwork(), null);
    expect(loadingCurrency.genesisBlock(), null);
    expect(loadingCurrency.deriveAddress(null, null), null);
    expect(loadingCurrency.fromPrivateKey(null), null);
    expect(loadingCurrency.fromPublicKey(null), null);
    expect(loadingCurrency.fromAddressJson(null), null);
    expect(loadingCurrency.fromPublicAddressJson(null), null);
    expect(loadingCurrency.fromPrivateKeyJson(null), null);
    expect(loadingCurrency.fromBlockIdJson(null), null);
    expect(loadingCurrency.fromTransactionIdJson(null), null);
    expect(loadingCurrency.fromTransactionJson(null), null);
    expect(
        loadingCurrency.signedTransaction(null, null, null, null, null, null),
        null);
  });
}
