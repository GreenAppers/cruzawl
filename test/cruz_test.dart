// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/test.dart';
import 'package:cruzawl/websocket_html.dart'
    if (dart.library.io) 'package:cruzawl/websocket_io.dart';

void main() {
  CruzTester(group, test, expect).run();

  test('CRUZ currency', () {
    Currency currency = cruz;
    expect(CRUZ.blocksUntilNewSeries, 1008);
    expect(CRUZ.cruzbitsPerCruz, 100000000);
    expect(CRUZ.initialCoinbaseReward, 50);
    expect(CRUZ.blocksUntilRewardHalving, 210000);
    expect(CruzPublicKey.size, 32);
    expect(CruzPrivateKey.size, 64);
    expect(CruzSignature.size, 64);
    expect(CruzChainCode.size, 32);
    expect(CruzTransactionId.size, 32);
    expect(CruzBlockId.size, 32);

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

    expect(currency.nullAddress.toJson(),
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
    expect(currency.suggestedFee(null), '0.01');
    expect(currency.parse(currency.suggestedFee(null)), 1000000);
    expect(currency.supply(210033), 10500825);
  });

  test('LoadingCurrency', () {
    Currency currency = loadingCurrency;

    expect(currency.ticker, cruz.ticker);
    expect(currency.parse('33'), 33);
    expect(currency.parseTime(43), DateTime.fromMillisecondsSinceEpoch(43000));
    expect(currency.supply(53), 0);
    expect(currency.bip44CoinType, 0);
    expect(currency.coinbaseMaturity, 0);
    expect(currency.nullAddress, null);
    expect(currency.createNetwork(), null);
    expect(currency.genesisBlock(), null);
    expect(currency.deriveAddress(null, null), null);
    expect(currency.fromPrivateKey(null), null);
    expect(currency.fromPublicKey(null), null);
    expect(currency.fromAddressJson(null), null);
    expect(currency.fromPublicAddressJson(null), null);
    expect(currency.fromPrivateKeyJson(null), null);
    expect(currency.fromBlockIdJson(null), null);
    expect(currency.fromTransactionIdJson(null), null);
    expect(currency.fromTransactionJson(null), null);
    expect(currency.suggestedFee(null), null);
    expect(
        currency.signedTransaction(null, null, null, null, null, null), null);
  });

  test('WebSocket connection to public seeder - require valid cert', () async {
    expect(WebSocketImpl.type, 'io');
    Completer<void> completer = Completer<void>();
    PeerNetwork network = cruz.createNetwork();
    network.tipChanged = () => completer.complete(null);
    network.addPeer(network.createPeerWithSpec(
        PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
            debugPrint: (x) {/* print('DEBUG: $x'); */}),
        cruz.genesisBlock().id().toJson()))
      ..connectAfter(1)
      ..connectAfter(0);
    await completer.future;
    BlockHeader block = network.tip;
    print('Found live tip height = ${block.height}');
    expect(block.height > 0, true);
    network.shutdown();
  });

  test('WebSocket connection to public seeder - ignore bad cert', () async {
    Completer<void> completer = Completer<void>();
    PeerNetwork network = cruz.createNetwork();
    network.autoReconnectSeconds = 0;
    network.tipChanged = () => completer.complete(null);
    Peer peer = network.addPeer(network.createPeerWithSpec(
        PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ',
            PeerPreference.formatOptions(ignoreBadCert: true),
            debugPrint: (x) {/* print('DEBUG: $x'); */}),
        cruz.genesisBlock().id().toJson()));
    network.peerStateChanged(
        peer, PeerState.connecting, PeerState.disconnected);

    await completer.future;
    BlockHeader block = network.tip;
    print('Found live tip height = ${block.height}');
    expect(block.height > 0, true);
    network.shutdown();
  });
}
