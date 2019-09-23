// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';

// bash-3.2$ dart example.dart
// *** Latest Block ***
// Height: 19527
void main() {
  PeerNetwork network = cruz.createNetwork();

  /// Print the latest [BlockHeader] in the block chain.
  network.tipChanged = () {
    print('*** Latest Block ***');
    print('Height: ${network.tipHeight}');
    exit(0);
  };

  /// Connect [PeerNetwork] to public seeder.
  network
      .addPeer(network.createPeerWithSpec(
          PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
              debugPrint: (x) {/* print('DEBUG: $x'); */})))
      .connect();
}
