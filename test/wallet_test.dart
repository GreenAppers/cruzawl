// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:bip39/bip39.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/test.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/websocket.dart';
import 'package:cruzawl/wallet.dart';

void main() {
  WalletTester(group, test, expect).run();

  Wallet wallet;
  CruzPeer peer;
  CruzawlPreferences preferences;
  TestWebSocket socket = TestWebSocket();
  PeerNetwork network = cruz.createNetwork();
  String moneyAddr,
      moneySender = 'xRL0D9U+jav9NxOwz4LsXe8yZ8KSS7Hst4/P8ChciAI=';
  int money = 13, moneyBalance = money * CRUZ.cruzbitsPerCruz;

  test('Create CruzawlPreferences', () async {
    preferences = CruzawlPreferences(
        SembastPreferences(
            await databaseFactoryMemoryFs.openDatabase('settings.db')),
        () => 'USD');
    await preferences.storage.load();
    await preferences.setNetworkEnabled(false);
    await preferences.setMinimumReserveAddress(3);
  });

  test('Create CruzPeer', () {
    PeerPreference peerPref = preferences.peers[0];
    peerPref.debugPrint = print;
    peerPref.debugLevel = debugLevelDebug;
    peer = network.addPeer(network.createPeerWithSpec(
        peerPref, cruz.genesisBlock().id().toJson()));
    peer.ws = socket;
  });

  test('CruzPeer connect', () {
    peer.connect();
    expect(socket.sent.length, 2);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_tip_header');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"tip_header","body":{"block_id":"0000000000000ab4ac72b9b6061cb19195fe1a8a6d5b961f793f6b61f6f9aa9c","header":{"previous":"0000000000003e69ff6f9e82aed1edf4fbeff282f483a155f15993a1d5b388f1","hash_list_root":"e621df23f3d1cbf31ff55eb35b58f149e1119f9bcaaeddbfd50a0492d761b3fe","time":1567226693,"target":"0000000000005a51944cead8d0ecf64b7b699564debb11582725296e08f6907b","chain_work":"0000000000000000000000000000000000000000000000001cac236eabb61ced","nonce":1339749016450629,"height":25352,"transaction_count":20},"time_seen":1567226903}}');

    msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_transaction_relay_policy');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"transaction_relay_policy","body":{"min_fee":1000000,"min_amount":1000000}}');

    expect(network.length, 1);
    expect(network.tipHeight, 25352);
    expect(network.tipId.toJson(),
        '0000000000000ab4ac72b9b6061cb19195fe1a8a6d5b961f793f6b61f6f9aa9c');
    expect(network.minFee, 1000000);
    expect(network.minAmount, 1000000);
    expect(network.peerState, PeerState.ready);
    expect(network.peerAddress,
        'wss://wallet.cruzbit.xyz:8831/00000000e29a7850088d660489b7b9ae2da763bc3bd83324ecc54eee04840adb');
  });

  test('CRUZ HD Wallet create', () async {
    Completer<void> completer = Completer<void>();
    wallet = Wallet.fromSeedPhrase(
        databaseFactoryMemoryFs,
        NullFileSystem(),
        'wallet.cruzall',
        'wallet',
        network,
        generateMnemonic(),
        preferences,
        print,
        (_) => completer.complete(null));
    await completer.future;
    expect(wallet.addresses.length, 3);
    for (var address in wallet.addresses.values) {
      address.state = AddressState.used;
    }
  });

  test('CRUZ HD Wallet filter_add', () async {
    expect(socket.sent.length, 3);
    for (int i = 0; i < 3; i++) {
      var msg = jsonDecode(socket.sent.first);
      expect(msg['type'], 'filter_add');
      expect(wallet.addresses.containsKey(msg['body']['public_keys'][0]), true);
      socket.sent.removeFirst();
      socket.messageHandler('{"type":"filter_result"}');
    }
  });

  test('CRUZ HD Wallet get_balance', () {
    expect(socket.sent.length, 3);
    for (int i = 0; i < 3; i++) {
      var msg = jsonDecode(socket.sent.first);
      expect(msg['type'], 'get_balance');
      String addr = msg['body']['public_key'];
      if (i == 0) moneyAddr = addr;
      int balance = i == 0 ? moneyBalance : 0;
      expect(wallet.addresses.containsKey(addr), true);
      socket.sent.removeFirst();
      socket.messageHandler(
          '{"type":"balance","body":{"block_id":"0000000000000ab4ac72b9b6061cb19195fe1a8a6d5b961f793f6b61f6f9aa9c","height":25352,"public_key":"$addr","balance":$balance}}');
    }
  });

  test('CRUZ HD Wallet get_public_key_transactions', () {
    expect(socket.sent.length, 3);
    for (int i = 0; i < 3; i++) {
      var msg = jsonDecode(socket.sent.first);
      expect(msg['type'], 'get_public_key_transactions');
      String addr = msg['body']['public_key'];
      expect(wallet.addresses.containsKey(addr), true);
      socket.sent.removeFirst();
      if (addr == moneyAddr) {
        socket.messageHandler(
            '{"type":"public_key_transactions","body":{"public_key":"$addr","start_height":25352,"stop_height":0,"stop_index":0,"filter_blocks":[{"block_id":"00000000000555de1d28a55fd2d5d2069c61fd46c4618cfea16c5adf6d902f4d","header":{"previous":"000000000001e0313c0536e700a8e6c02b2fc6bbddb755d749d6e00746d52b2b","hash_list_root":"3c1b3f728653444e8bca498bf5a6d76a259637e592f749ad881f1f1da0087db0","time":1564553276,"target":"000000000007a38c469f3be96898a11435ea27592c2bae351147392e9cd3408d","chain_work":"00000000000000000000000000000000000000000000000000faa7649c97e894","nonce":1989109050083893,"height":17067,"transaction_count":2},"transactions":[{"time":1564550817,"nonce":1130916028,"from":"$moneySender","to":"$addr","amount":$moneyBalance,"fee":1000000,"expires":17068,"series":17,"signature":"mcvGJ59Q9U9j5Tbjk/gIKYPFmz3lXNb3t8DwkznINJWI7uFPymmywBJjE18UzL2+MMicm0xbyKVJ3XEvQiQ5BQ=="}]}]}}');
      } else {
        socket.messageHandler(
            '{"type":"public_key_transactions","body":{"public_key":"$addr","start_height":25352,"stop_height":0,"stop_index":0,"filter_blocks":null}}');
      }
    }
  });

  test('CRUZ HD Wallet get_filter_transaction_queue', () {
    expect(socket.sent.length, 1);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_filter_transaction_queue');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"filter_transaction_queue","body":{"transactions":null}}');
  });

  test('CRUZ HD Wallet loaded', () {
    expect(socket.sent.length, 0);
    expect(wallet.balance, moneyBalance);
  });

  test('CRUZ HD Wallet new tip', () {
    socket.messageHandler('{"type":"inv_block","body":{"block_ids":["0000000000002942708257841501a15b56f11aeb670b95a5b113216ca6dbba1a"]}}');
    socket.messageHandler('{"type":"filter_block","body":{"block_id":"0000000000002942708257841501a15b56f11aeb670b95a5b113216ca6dbba1a","header":{"previous":"0000000000000b6a264d8b65fb9be5b7d8e9624e51b3d384c9859cadb8328b59","hash_list_root":"8ddde311055b51e4c0336c2f02f5233fce6c58e726d87ede9e9566179a043b45","time":1568351002,"target":"0000000000002e8e541746a412fea54fb1cfba570f238922ed91f5a51cd9a881","chain_work":"00000000000000000000000000000000000000000000000042c188bd69f5d21a","nonce":197164610255140,"height":25353,"transaction_count":1},"transactions":null}}');
    expect(network.tipHeight, 25353);
  });

  test('CRUZ HD Wallet reload', () async {
    preferences.setMinimumReserveAddress(0);
    Seed seed = wallet.seed;
    List<Address> addresses = wallet.addresses.values.toList();
    Completer<void> completer = Completer<void>();
    wallet = Wallet.fromFile(
        databaseFactoryMemoryFs,
        <PeerNetwork>[network],
        NullFileSystem(),
        'wallet.cruzall',
        seed,
        preferences,
        print,
        (_) => completer.complete(null));
    expect(wallet.currency, loadingCurrency);
    await completer.future;
    expect(wallet.currency, cruz);
    expect(wallet.addresses.length, 3);
    for (var address in wallet.addresses.values) {
      address.state = AddressState.used;
    }
    List<Address> reloadAddresses = wallet.addresses.values.toList();
    addresses.sort(Address.compareIndex);
    reloadAddresses.sort(Address.compareIndex);
    for (int i = 0; i < addresses.length; i++) {
      expect(reloadAddresses[i].publicKey.toJson(),
          addresses[i].publicKey.toJson());
      expect(reloadAddresses[i].privateKey.toJson(),
          addresses[i].privateKey.toJson());
      expect(reloadAddresses[i].balance, addresses[i].balance);
    }
  });

  test('CruzPeerNetwork shutdown', () async {
    expect(network.hasPeer, true);
    network.shutdown();
    expect(network.hasPeer, false);
  });
}
