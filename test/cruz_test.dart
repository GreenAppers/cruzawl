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

  test('LoadingCurrency', () {
    expect(loadingCurrency.bip44CoinType, 0);
  });

  test('WebSocket connection to public seeder', () async {
    Completer<void> completer = Completer<void>();
    PeerNetwork network = cruz.createNetwork();
    network.tipChanged = () => completer.complete(null);
    network
        .addPeer(network.createPeerWithSpec(
            PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ', ',ignoreBadCert,',
                debugPrint: (x) { /* print('DEBUG: $x'); */ }),
            cruz.genesisBlock().id().toJson()))
        .connect();

    await completer.future;
    BlockHeader block = network.tip;
    print('Found tip height = ${block.height}');
    expect(block.height > 0, true);

    network.shutdown();
  });
}
