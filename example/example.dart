// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';

// bash-3.2$ dart example.dart 
// *** Latest Block ***
// Height: 19527
// Id: 00000000000466a45c60eb8f69345ec3d64af44fad31eccb3cc922faef27fdb2
// Previous: 000000000002b57d4e0db7eb1209b289112bc4af5d81e15d5ce3700ee646f28b
// Transactions: 4
void main() {
  PeerNetwork network = cruz.createNetwork();

  /// Print the latest [BlockHeader] in the block chain.
  network.tipChanged = () {
    BlockHeader block = network.tip;
    print('*** Latest Block ***');
    print('Height: ${block.height}');
    print('Id: ${network.tipId.toJson()}');
    print('Previous: ${block.previous.toJson()}');
    print('Transactions: ${block.transactionCount}');
    exit(0);
  };

  /// Connect [PeerNetwork] to public seeder.
  network
      .addPeer(network.createPeerWithSpec(
          PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
              debugPrint: (x) { /* print('DEBUG: $x'); */ }),
          cruz.genesisBlock().id().toJson()))
      .connect();
}

