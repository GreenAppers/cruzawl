// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:console/console.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';

// bash-3.2$ dart cruzawl.dart
// *** Latest Block ***
// Height: 19527
void main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addOption('currency', abbr: 'c')
    ..addOption('url', abbr: 'u')
    ..addOption('root', abbr: 'r')
    ..addOption('sshUrl')
    ..addOption('sshUser')
    ..addOption('sshPassword')
    ..addOption('sshKey');

  final ArgResults args = argParser.parse(arguments);
  final String currencyName = (args['currency'] ?? 'CRUZ').toUpperCase();
  final Currency currency = Currency.fromJson(currencyName);

  if (currency == null) {
    print(format('{color.red}Unsupported currency{color.end}: $currencyName'));
    exit(1);
  }

  final PeerNetwork network = currency.createNetwork();
  final String peerUrl =
      args['url'] ?? (currencyName == 'CRUZ' ? 'wallet.cruzbit.xyz' : null);

  if (peerUrl == null || peerUrl.isEmpty) {
    print(format('{color.red}Unspecified peer URL{color.end}'));
    exit(1);
  }

  print(format(
      'Cruzawl for {color.cyan}${currency.ticker}{color.end}: {color.white}${currency.name}'));

  /// Print the latest [BlockHeader] in the block chain.
  network.tipChanged = () {
    print(format(
        '{color.red}*** {color.gold}Latest Block {color.red}***{color.end}'));
    print('Height: ${network.tipHeight}');
  };

  /// Connect [PeerNetwork] to public seeder.
  network
      .addPeer(network.createPeerWithSpec(PeerPreference(
        'Peer configured by command line',
        peerUrl,
        currency.ticker,
        '',
        debugPrint: (x) => print(x),
        sshUrl: args['sshUrl'],
        sshUser: args['sshUser'],
        sshPassword: args['sshPassword'],
      )))
      .connect();

  /// Serve CLI
  var subscription;
  subscription = stdin.transform(utf8.decoder).listen((String input) {
    String line = input.trim(), lowerLine = line.toLowerCase();

    if (["stop", "quit", "exit"].contains(lowerLine)) {
      subscription.cancel();
      network.shutdown();
      return;
    }

    print(line);
  });
}
