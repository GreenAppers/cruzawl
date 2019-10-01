// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

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

String moneyAddr, pushedTransactionId;

const num sendMoney = 3.29, feeMoney = 0.01, startingTipHeight = 25352;
const int money = 13, moneyBalance = money * CRUZ.cruzbitsPerCruz;
const int sendMoneyBalance = (sendMoney * CRUZ.cruzbitsPerCruz) ~/ 1;
const int feeMoneyBalance = (feeMoney * CRUZ.cruzbitsPerCruz) ~/ 1;
const int sentMoneyBalance = moneyBalance - sendMoneyBalance - feeMoneyBalance;
const int rewardMoneyBalance = 50 * CRUZ.cruzbitsPerCruz;
const int firstBlockTime = 1567226693, newBlockTime = firstBlockTime + 100;
const String moneySender = 'xRL0D9U+jav9NxOwz4LsXe8yZ8KSS7Hst4/P8ChciAI=';
const String sendTo = '5lojzpXqrpAfrYSxF0s8vyRSQ0SlhiovzacD+tI1oK8=';
const String firstBlockId =
    '0000000000000ab4ac72b9b6061cb19195fe1a8a6d5b961f793f6b61f6f9aa9c';
const String newBlockId =
    '0000000000002942708257841501a15b56f11aeb670b95a5b113216ca6dbba1a';
const String firstBlockWork =
    '0000000000000000000000000000000000000000000000001cac236eabb61ced';
const String newBlockWork =
    '0000000000000000000000000000000000000000000000001fc188bd69f5d21a';

String moneyTransaction1(String addr) =>
    '{"time":1564510000,"nonce":1130919999,"to":"$addr","amount":$rewardMoneyBalance,"fee":0,"expires":17068,"series":17,"signature":"mcvGJ59Q9U9j5Tbjk/gIKYPFmz3lXNb3t8DwkznINJWI7uFPymmywBJjE18UzL2+MMicm0xbyKVJ3XEvQiQ5BQ=="}';

String moneyTransaction2(String addr) =>
    '{"time":1564550817,"nonce":1130916028,"from":"$moneySender","to":"$addr","amount":$moneyBalance,"fee":1000000,"expires":17068,"series":17,"signature":"mcvGJ59Q9U9j5Tbjk/gIKYPFmz3lXNb3t8DwkznINJWI7uFPymmywBJjE18UzL2+MMicm0xbyKVJ3XEvQiQ5BQ=="}';

void main() {
  Wallet wallet;
  CruzPeer peer;
  CruzawlPreferences preferences;
  TestWebSocket socket = TestWebSocket();
  PeerNetwork network = cruz.createNetwork(tipChanged: () {
    if (wallet != null) wallet.updateTip();
  });
  Transaction sendTransaction;

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
    expect(network.peerState, PeerState.disconnected);
    expect(network.peerAddress, '');
    PeerPreference peerPref = preferences.peers[0];
    peerPref.debugPrint = print;
    peerPref.debugLevel = debugLevelDebug;
    peer = network.addPeer(network.createPeerWithSpec(peerPref));
    peer.ws = socket;
    expect(network.peerState, PeerState.disconnected);
    expect(network.peerAddress, peer.address);
  });

  test('Connect CruzPeer', () {
    expect(network.peerState, PeerState.disconnected);
    Future<Peer> getPeer = network.getPeer();
    peer.connect();
    expect(network.peerState, PeerState.connected);
    expect(socket.sent.length, 2);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_tip_header');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"tip_header","body":{"block_id":"$firstBlockId","header":{"previous":"0000000000003e69ff6f9e82aed1edf4fbeff282f483a155f15993a1d5b388f1","hash_list_root":"e621df23f3d1cbf31ff55eb35b58f149e1119f9bcaaeddbfd50a0492d761b3fe","time":$firstBlockTime,"target":"0000000000005a51944cead8d0ecf64b7b699564debb11582725296e08f6907b","chain_work":"$firstBlockWork","nonce":1339749016450629,"height":$startingTipHeight,"transaction_count":20},"time_seen":1567226903}}');

    msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_transaction_relay_policy');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"transaction_relay_policy","body":{"min_fee":1000000,"min_amount":1000000}}');

    expect(network.length, 1);
    expect(network.tipHeight, startingTipHeight);
    expect(network.tipId.toJson(), firstBlockId);
    expect(network.minFee, 1000000);
    expect(network.minAmount, 1000000);
    expect(network.peerState, PeerState.ready);
    expect(network.peerAddress,
        'wss://wallet.cruzbit.xyz:8831/00000000e29a7850088d660489b7b9ae2da763bc3bd83324ecc54eee04840adb');
    expect(getPeer, completion(equals(peer)));
  });

  test('Create CRUZ HD Wallet', () async {
    Completer<void> completer = Completer<void>();
    wallet = Wallet.generate(
        databaseFactoryMemoryFs,
        NullFileSystem(),
        'wallet.cruzall',
        'wallet',
        network,
        preferences,
        print,
        (_) => completer.complete(null));
    await completer.future;
    expect(wallet.addresses.length, 3);
    for (var address in wallet.addresses.values) {
      address.state = AddressState.used;
      expect(address.verify(), true);
    }

    await expectWalletLoadProtocol(wallet.addresses, socket,
        setMoneyAddr: true);
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect(wallet.balance, moneyBalance);
    expect(wallet.maturesBalance, rewardMoneyBalance);
    expect(wallet.transactions.isEmpty, false);
    expect(wallet.transactions.length, 2);
    CruzTransaction transaction1 =
        cruz.fromTransactionJson(jsonDecode(moneyTransaction1(moneyAddr)));
    CruzTransaction transaction2 =
        cruz.fromTransactionJson(jsonDecode(moneyTransaction2(moneyAddr)));
    expectTransactionEqual(wallet.transactions.first, transaction2);
    expectTransactionEqual(wallet.transactions.last, transaction1);
    expect(wallet.addresses.values.reduce(Address.reduceBalance),
        wallet.addresses[moneyAddr]);
    expect(
        Address.compareBalance(
            wallet.addresses.values.last, wallet.addresses.values.first),
        moneyBalance);
  });

  test('Send from CRUZ HD Wallet', () async {
    Address fromAddress = wallet.addresses[moneyAddr];
    expect(wallet.balance, moneyBalance);
    expect(fromAddress.balance, moneyBalance);
    expect(cruz.parse('$sendMoney'), sendMoneyBalance);
    sendTransaction = await wallet.createTransaction(wallet.currency
        .signedTransaction(
            fromAddress,
            wallet.currency.fromPublicAddressJson(sendTo),
            sendMoneyBalance,
            feeMoneyBalance,
            'memofoo',
            wallet.network.tipHeight,
            expires: wallet.network.tipHeight + 1));
    expect(sendTransaction.verify(), true);
    Future<TransactionId> sendTransactionId =
        peer.putTransaction(sendTransaction);

    expect(socket.sent.length, 1);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'push_transaction');
    CruzTransaction pushedTransaction =
        cruz.fromTransactionJson(msg['body']['transaction']);
    expect(pushedTransaction.from.toJson(), moneyAddr);
    expect(pushedTransaction.to.toJson(), sendTo);
    expect(pushedTransaction.amount, sendMoneyBalance);
    expect(pushedTransaction.verify(), true);
    expect(wallet.pendingCount, 1);

    pushedTransactionId = pushedTransaction.id().toJson();
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"push_transaction_result","body":{"transaction_id":"$pushedTransactionId"}}');
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect((await sendTransactionId).toJson(), pushedTransactionId);
    expect(wallet.transactions.length, 3);
    CruzTransaction transaction1 =
        cruz.fromTransactionJson(jsonDecode(moneyTransaction1(moneyAddr)));
    expectTransactionEqual(wallet.transactions.last, transaction1);
    expectTransactionEqual(wallet.transactions.first, sendTransaction);
    expect(wallet.transactions.first.height, 0);

    socket.messageHandler(
        '{"type":"push_transaction","body":{"transaction":${jsonEncode(sendTransaction)}}}');
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect(wallet.pendingCount, 1);
    expect(wallet.balance, sentMoneyBalance);
    expectTransactionEqual(wallet.transactions.first, sendTransaction);
    expect(wallet.transactions.first.height, 0);
  });

  test('Reload CRUZ HD Wallet', () async {
    await preferences.setMinimumReserveAddress(0);
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
      expect(address.verify(), true);
    }
    List<Address> reloadAddresses = wallet.addresses.values.toList();
    addresses.sort(Address.compareIndex);
    reloadAddresses.sort(Address.compareIndex);
    for (int i = 0; i < addresses.length; i++) {
      expect(reloadAddresses[i].publicAddress.toJson(),
          addresses[i].publicAddress.toJson());
      expect(reloadAddresses[i].privateKey.toJson(),
          addresses[i].privateKey.toJson());
      expect(reloadAddresses[i].balance, addresses[i].balance);
    }

    await expectWalletLoadProtocol(wallet.addresses, socket);
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect(wallet.balance, sentMoneyBalance);
    expect(wallet.pendingCount, 1);
  });

  test('New tip for CRUZ HD Wallet', () async {
    expect(network.tipHeight, startingTipHeight);
    expect(wallet.pendingCount, 1);
    expect(wallet.balance, sentMoneyBalance);
    expect(wallet.maturesBalance, rewardMoneyBalance);
    CruzBlockIds blockIds =
        CruzBlockIds.fromJson(jsonDecode('{"block_ids":["$newBlockId"]}'));
    socket
        .messageHandler('{"type":"inv_block","body":${jsonEncode(blockIds)}}');
    socket.messageHandler(
        '{"type":"filter_block","body":{"block_id":"$newBlockId","header":{"previous":"0000000000000b6a264d8b65fb9be5b7d8e9624e51b3d384c9859cadb8328b59","hash_list_root":"8ddde311055b51e4c0336c2f02f5233fce6c58e726d87ede9e9566179a043b45","time":$newBlockTime,"target":"0000000000002e8e541746a412fea54fb1cfba570f238922ed91f5a51cd9a881","chain_work":"$newBlockWork","nonce":197164610255140,"height":${startingTipHeight + 1},"transaction_count":2},"transactions":[${jsonEncode(sendTransaction)}]}}');
    await pumpEventQueue();
    expect(network.tipHeight, startingTipHeight + 1);
    expect(wallet.pendingCount, 0);
    expect(wallet.balance, sentMoneyBalance + rewardMoneyBalance);
    expect(wallet.maturesBalance, 0);
    expect(wallet.transactions.length, 3);
    expectTransactionEqual(wallet.transactions.first, sendTransaction);
    expect(wallet.transactions.first.height, startingTipHeight + 1);
  });

  test('CRUZ Block stats', () async {
    Future<BlockMessage> blockFuture = peer.getBlock(height: startingTipHeight);
    expect(socket.sent.length, 1);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_block_by_height');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"block","body":{"block_id":"$firstBlockId","block":{"header":{"previous":"0000000000003e69ff6f9e82aed1edf4fbeff282f483a155f15993a1d5b388f1","hash_list_root":"e621df23f3d1cbf31ff55eb35b58f149e1119f9bcaaeddbfd50a0492d761b3fe","time":$firstBlockTime,"target":"0000000000005a51944cead8d0ecf64b7b699564debb11582725296e08f6907b","chain_work":"$firstBlockWork","nonce":1339749016450629,"height":$startingTipHeight,"transaction_count":1},"transactions":[{"time":1568684206,"nonce":754321990,"to":"vsiyJaIGuqnllrktuSaF5eI5Oo962jdM2FUm6tOfqnI=","amount":5000000000,"memo":"cruzpool v0.31 🐛","series":29}]}}}');
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    BlockMessage block = await blockFuture;
    expect(block.id.toJson(), firstBlockId);

    Future<BlockHeaderMessage> blockHeaderFuture =
        peer.getBlockHeader(height: startingTipHeight + 1);
    expect(socket.sent.length, 1);
    msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_block_header_by_height');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"block_header","body":{"block_id":"$newBlockId","header":{"previous":"0000000000000b6a264d8b65fb9be5b7d8e9624e51b3d384c9859cadb8328b59","hash_list_root":"8ddde311055b51e4c0336c2f02f5233fce6c58e726d87ede9e9566179a043b45","time":$newBlockTime,"target":"0000000000002e8e541746a412fea54fb1cfba570f238922ed91f5a51cd9a881","chain_work":"$newBlockWork","nonce":197164610255140,"height":${startingTipHeight + 1},"transaction_count":2},"transactions":[${jsonEncode(sendTransaction)}]}}');
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    BlockHeaderMessage blockHeader = await blockHeaderFuture;
    expect(blockHeader.id.toJson(), newBlockId);
    expect(blockHeader.header.blockWork(), BigInt.from(1547762683702922));
    expect(blockHeader.header.deltaTime(block.block.header).inSeconds,
        newBlockTime - firstBlockTime);
    expect(blockHeader.header.hashRate(block.block.header), 2221951454984082);
    expect(
        BlockHeader.compareHeight(block.block.header, blockHeader.header), 1);

    Future<TransactionMessage> transactionFuture =
        peer.getTransaction(cruz.fromTransactionIdJson(pushedTransactionId));
    expect(socket.sent.length, 1);
    msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_transaction');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"transaction","body":{"block_id":"$newBlockId","height":${startingTipHeight + 1},"transaction_id":"$pushedTransactionId","transaction":${jsonEncode(sendTransaction)}}}');
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    TransactionMessage transaction = await transactionFuture;
    expect(transaction.id.toJson(), pushedTransactionId);
    expect(transaction.transaction.inputs.length, 1);
    expect(transaction.transaction.inputs[0].address.toJson(), moneyAddr);
    expect(
        Transaction.maturityCompare(
            transaction.transaction, transaction.transaction),
        0);
  });

  test('Reorg for CRUZ HD Wallet', () async {
    expect(wallet.pendingCount, 0);
    expect(wallet.maturesBalance, 0);
    expect(wallet.balance, sentMoneyBalance + rewardMoneyBalance);
    expect(network.tipHeight, startingTipHeight + 1);
    expect(wallet.transactions.length, 3);

    // undo block
    socket.messageHandler(
        '{"type":"filter_block_undo","body":{"block_id":"$newBlockId","header":{"previous":"0000000000000b6a264d8b65fb9be5b7d8e9624e51b3d384c9859cadb8328b59","hash_list_root":"8ddde311055b51e4c0336c2f02f5233fce6c58e726d87ede9e9566179a043b45","time":$newBlockTime,"target":"0000000000002e8e541746a412fea54fb1cfba570f238922ed91f5a51cd9a881","chain_work":"$newBlockWork","nonce":197164610255140,"height":${startingTipHeight + 1},"transaction_count":2},"transactions":[${jsonEncode(sendTransaction)}]}}');
    await pumpEventQueue();
    expect(wallet.transactions.length, 2);
    expect(wallet.balance, moneyBalance + rewardMoneyBalance);

    // then redo it
    socket.messageHandler(
        '{"type":"inv_block","body":{"block_ids":["$newBlockId"]}}');
    socket.messageHandler(
        '{"type":"filter_block","body":{"block_id":"$newBlockId","header":{"previous":"0000000000000b6a264d8b65fb9be5b7d8e9624e51b3d384c9859cadb8328b59","hash_list_root":"8ddde311055b51e4c0336c2f02f5233fce6c58e726d87ede9e9566179a043b45","time":$newBlockTime,"target":"0000000000002e8e541746a412fea54fb1cfba570f238922ed91f5a51cd9a881","chain_work":"$newBlockWork","nonce":197164610255140,"height":${startingTipHeight + 1},"transaction_count":2},"transactions":[${jsonEncode(sendTransaction)}]}}');
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect(wallet.pendingCount, 0);
    expect(wallet.maturesBalance, 0);
    expect(network.tipHeight, startingTipHeight + 1);
    expect(wallet.balance, sentMoneyBalance + rewardMoneyBalance);
    expect(wallet.transactions.length, 3);
    expectTransactionEqual(wallet.transactions.first, sendTransaction);
    expect(wallet.transactions.first.height, startingTipHeight + 1);
  });

  test('Create new CRUZ HD Wallet address', () async {
    Map<String, Address> addresses =
        Map<String, Address>.from(wallet.addresses);
    expect(addresses.length, 3);
    Address receiveAddress = wallet.receiveAddress;
    String receiveAddressText = receiveAddress.publicAddress.toJson();
    expect(addresses.containsKey(receiveAddressText), true);
    wallet.addresses[receiveAddressText].state = AddressState.reserve;
    await preferences.setMinimumReserveAddress(3);
    await wallet.updateAddressState(receiveAddress, AddressState.open);
    expect(wallet.addresses.length, 4);
    Address newReceiveAddress = wallet.receiveAddress;
    String newReceiveAddressText = newReceiveAddress.publicAddress.toJson();
    expect(addresses.containsKey(newReceiveAddressText), true);
    expect(receiveAddressText == newReceiveAddressText, false);
    Set<String> newAddr =
        Set.of(wallet.addresses.keys).difference(Set.of(addresses.keys));
    expect(newAddr.length, 1);
    String newAddressText = newAddr.first;
    Address newAddress = wallet.addresses[newAddressText];
    expect(newAddress.publicAddress.toJson(), newAddressText);
    await preferences.setMinimumReserveAddress(0);
    await expectWalletLoadProtocol({newAddressText: newAddress}, socket,
        filterTxnQueue: false);
    await pumpEventQueue();
    expect(socket.sent.length, 0);
  });

  test('Create CRUZ non-HD Wallet', () async {
    await preferences.setMinimumReserveAddress(3);
    Completer<void> completer = Completer<void>();
    Seed seed = Seed(randBytes(64));
    Wallet nonHdWallet = Wallet.fromPrivateKeyList(
        databaseFactoryMemoryFs,
        NullFileSystem(),
        'non-hd-wallet.cruzall',
        'non-hd-wallet',
        network,
        seed,
        <PrivateKey>[wallet.addresses[moneyAddr].privateKey],
        preferences,
        print,
        (_) => completer.complete(null));
    await completer.future;
    expect(nonHdWallet.addresses.length, 1);
    for (var address in nonHdWallet.addresses.values) {
      expect(address.state, AddressState.used);
      expect(address.verify(), true);
    }

    await expectWalletLoadProtocol(nonHdWallet.addresses, socket);
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect(nonHdWallet.balance, moneyBalance);
    expect(nonHdWallet.maturesBalance, 0);
    expect(nonHdWallet.receiveAddress.publicAddress.toJson(), moneyAddr);
  });

  test('Create CRUZ watch-only Wallet - throttled', () async {
    /// Set [Peer.maxOutstanding] to one, then clog the queue with one get_transaction query
    peer.maxOutstanding = 1;
    Future<TransactionMessage> transactionFuture =
        peer.getTransaction(cruz.fromTransactionIdJson(pushedTransactionId));
    expect(socket.sent.length, 1);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_transaction');

    // Create a new watch-only wallet
    await preferences.setMinimumReserveAddress(3);
    Completer<void> completer = Completer<void>();
    Seed seed = Seed(randBytes(64));
    Wallet watchOnlyWallet = Wallet.fromPublicKeyList(
        databaseFactoryMemoryFs,
        NullFileSystem(),
        'watch-only-wallet.cruzall',
        'watch-only-wallet',
        network,
        seed,
        <PublicAddress>[wallet.addresses[moneyAddr].publicAddress],
        preferences,
        print,
        (_) => completer.complete(null));
    await pumpEventQueue();

    // Finally answer our query
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"transaction","body":{"block_id":"$newBlockId","height":${startingTipHeight + 1},"transaction_id":"$pushedTransactionId","transaction":${jsonEncode(sendTransaction)}}}');
    await pumpEventQueue();
    expect(socket.sent.length, 1);
    TransactionMessage transaction = await transactionFuture;
    expect(transaction.id.toJson(), pushedTransactionId);
    expect(transaction.transaction.inputs.length, 1);
    expect(transaction.transaction.inputs[0].address.toJson(), moneyAddr);

    // And complete wallet load
    await completer.future;
    expect(watchOnlyWallet.addresses.length, 1);
    for (var address in watchOnlyWallet.addresses.values) {
      expect(address.state, AddressState.used);
      expect(address.verify(), false);
    }

    await expectWalletLoadProtocol(watchOnlyWallet.addresses, socket);
    await pumpEventQueue();
    expect(socket.sent.length, 0);
    expect(watchOnlyWallet.balance, moneyBalance);
    expect(watchOnlyWallet.maturesBalance, 0);
    expect(watchOnlyWallet.receiveAddress.publicAddress.toJson(), moneyAddr);
  });

  test('Shutdown CruzPeerNetwork', () async {
    expect(network.hasPeer, true);
    network.shutdown();
    expect(network.hasPeer, false);
  });
}

void expectTransactionEqual(Transaction txn1, Transaction txn2) {
  //expect(txn1.height, txn2.height);
  expect(txn1.dateTime, txn2.dateTime);
  expect(txn1.nonce, txn2.nonce);
  if (txn1.inputs == null || txn2.inputs == null) {
    expect(txn1.inputs, txn2.inputs);
  } else {
    expect(txn1.inputs.length, txn2.inputs.length);
    for (int i = 0; i < txn1.inputs.length; i++) {
      expect(txn1.inputs[i].value, txn2.inputs[i].value);
      expect(txn1.inputs[i].fromText, txn2.inputs[i].fromText);
    }
  }
  expect(txn1.outputs.length, txn2.outputs.length);
  for (int i = 0; i < txn1.outputs.length; i++) {
    expect(txn1.outputs[i].value, txn2.outputs[i].value);
    expect(txn1.outputs[i].toText, txn2.outputs[i].toText);
  }
  expect(txn1.amount, txn2.amount);
  expect(txn1.fee, txn2.fee);
  expect(txn1.memo, txn2.memo);
  expect(txn1.matures, txn2.matures);
  expect(txn1.expires, txn2.expires);
}

void expectWalletLoadProtocol(
    Map<String, Address> addresses, TestWebSocket socket,
    {bool setMoneyAddr = false, bool filterTxnQueue = true}) async {
  int length = addresses.length;
  expect(length > 0, true);

  // filter_add
  await pumpEventQueue();
  expect(socket.sent.length, length);
  for (int i = 0; i < length; i++) {
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'filter_add');
    expect(addresses.containsKey(msg['body']['public_keys'][0]), true);
    socket.sent.removeFirst();
    socket.messageHandler('{"type":"filter_result"}');
  }

  // get_balance
  await pumpEventQueue();
  expect(socket.sent.length, length);
  for (int i = 0; i < length; i++) {
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_balance');
    String addr = msg['body']['public_key'];
    if (i == 0 && setMoneyAddr) moneyAddr = addr;
    int balance = i == 0 ? moneyBalance : 0;
    expect(addresses.containsKey(addr), true);
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"balance","body":{"block_id":"$firstBlockId","height":$startingTipHeight,"public_key":"$addr","balance":$balance}}');
  }

  // get_public_key_transactions
  await pumpEventQueue();
  expect(socket.sent.length, length);
  for (int i = 0; i < length; i++) {
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_public_key_transactions');
    String addr = msg['body']['public_key'];
    expect(addresses.containsKey(addr), true);
    socket.sent.removeFirst();
    if (addr == moneyAddr) {
      /// Give [moneyAddr] 13 CRUZ with 50 CRUZ maturing the next block.
      int blockHeight = startingTipHeight - 99;
      socket.messageHandler(
          '{"type":"public_key_transactions","body":{"public_key":"$addr","start_height":$startingTipHeight,"stop_height":0,"stop_index":0,"filter_blocks":[{"block_id":"00000000000555de1d28a55fd2d5d2069c61fd46c4618cfea16c5adf6d902f4d","header":{"previous":"000000000001e0313c0536e700a8e6c02b2fc6bbddb755d749d6e00746d52b2b","hash_list_root":"3c1b3f728653444e8bca498bf5a6d76a259637e592f749ad881f1f1da0087db0","time":1564553276,"target":"000000000007a38c469f3be96898a11435ea27592c2bae351147392e9cd3408d","chain_work":"00000000000000000000000000000000000000000000000000faa7649c97e894","nonce":1989109050083893,"height":$blockHeight,"transaction_count":2},"transactions":[${moneyTransaction1(addr)},${moneyTransaction2(addr)}]}]}}');
    } else {
      socket.messageHandler(
          '{"type":"public_key_transactions","body":{"public_key":"$addr","start_height":$startingTipHeight,"stop_height":0,"stop_index":0,"filter_blocks":null}}');
    }
  }

  if (filterTxnQueue) {
    // get_filter_transaction_queue
    await pumpEventQueue();
    expect(socket.sent.length, 1);
    var msg = jsonDecode(socket.sent.first);
    expect(msg['type'], 'get_filter_transaction_queue');
    socket.sent.removeFirst();
    socket.messageHandler(
        '{"type":"filter_transaction_queue","body":{"transactions":null}}');
  }
}
