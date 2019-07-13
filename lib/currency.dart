// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/network.dart';

abstract class Currency {
  const Currency();

  factory Currency.fromJson(String x) {
    switch (x) {
      case 'CRUZ':
        return cruz;
      default:
        return null;
    }
  }

  String toJson() => ticker;
  String format(num v) => v.toString();
  String formatTime(int time) => time.toString();
  String formatHashRate(int hashesPerSec) {
    if (hashesPerSec > 1000000000) return '${hashesPerSec~/1000000000} GH/s';
    if (hashesPerSec > 1000000)    return '${hashesPerSec~/1000000} MH/s';
    else return '$hashesPerSec H/S';
  }
  String suggestedFee(Transaction t) => null;
  num parse(String v) => num.tryParse(v) ?? 0;

  String get ticker;
  int get bip44CoinType;
  PeerNetwork get network;

  String genesisBlockId();
  Address deriveAddress(Uint8List seed, String path);
  Address fromAddressJson(Map<String, dynamic> json);
  PublicAddress fromPublicAddressJson(String text);
  TransactionId fromTransactionIdJson(String text);
  Transaction fromTransactionJson(Map<String, dynamic> json);
  Transaction signedTransaction(Address from, PublicAddress to, num amount,
      num fee, String memo, int height,
      {int matures, int expires});
}

class LoadingCurrency extends Currency {
  const LoadingCurrency();

  String get ticker => 'CRUZ';
  int get bip44CoinType => 0;
  PeerNetwork get network => null;

  String genesisBlockId() => null;
  Address deriveAddress(Uint8List seed, String path) => null;
  Address fromAddressJson(Map<String, dynamic> json) => null;
  PublicAddress fromPublicAddressJson(String text) => null;
  TransactionId fromTransactionIdJson(String text) => null;
  Transaction fromTransactionJson(Map<String, dynamic> json) => null;
  Transaction signedTransaction(Address from, PublicAddress to, num amount,
          num fee, String memo, int height,
          {int matures, int expires}) =>
      null;
}

abstract class PublicAddress {
  String toJson();
}

abstract class PrivateKey {
  String toJson();
}

abstract class Signature {
  String toJson();
}

abstract class ChainCode {
  String toJson();
}

enum AddressState { reserve, open, used, remove }

abstract class Address {
  String name;
  AddressState state = AddressState.reserve;
  int accountId, chainIndex, earliestSeen, latestSeen;
  num balance = 0;

  // JSON ignore
  int maturesHeight = 0, loadedHeight, loadedIndex;
  num maturesBalance = 0, newBalance, newMaturesBalance;

  PublicAddress get publicKey;
  PrivateKey get privateKey;
  ChainCode get chainCode;

  Map<String, dynamic> toJson();

  void updateSeenHeight(int height) {
    if (latestSeen == null || height > latestSeen) latestSeen = height;
    if (earliestSeen == null || height < earliestSeen) earliestSeen = height;
  }

  static int compareIndex(dynamic a, dynamic b) {
    int accountDiff = a.accountId - b.accountId;
    return accountDiff != 0 ? accountDiff : a.chainIndex - b.chainIndex;
  }

  static int compareBalance(dynamic a, dynamic b) {
    int balanceDiff = b.balance - a.balance;
    return balanceDiff != 0 ? balanceDiff : compareIndex(a, b);
  }

  static Address reduceBalance(Address a, Address b) =>
      b.balance > a.balance ? b : a;
}

abstract class TransactionId {
  String toJson();
}

abstract class Transaction {
  int height = 0;

  int get time;
  int get nonce;
  PublicAddress get from;
  PublicAddress get to;
  num get amount;
  num get fee;
  String get memo;
  int get matures;
  int get expires;

  String get fromText => from.toJson();
  String get toText => to.toJson();
  int get maturity => max(matures ?? 0, from != null ? 0 : height + 100);

  Map<String, dynamic> toJson();
  TransactionId id();
  bool verify();

  static int timeCompare(Transaction a, Transaction b) {
    int deltaT = -a.time + b.time;
    return deltaT != 0 ? deltaT : a.id().toJson().compareTo(b.id().toJson());
  }

  static int maturityCompare(Transaction a, Transaction b) {
    int deltaM = a.maturity - b.maturity;
    return deltaM != 0 ? deltaM : a.id().toJson().compareTo(b.id().toJson());
  }
}

typedef TransactionCallback = void Function(Transaction);

class TransactionIterator {
  int height, index;
  TransactionIterator(this.height, this.index);
}

class TransactionIteratorResults extends TransactionIterator {
  List<Transaction> transactions;
  TransactionIteratorResults(int height, int index, this.transactions)
      : super(height, index);
}

abstract class BlockId {
  Uint8List data;
  String toJson();
}

abstract class BlockHeader {
  BlockId get previous;
  TransactionId get hashListRoot;
  int get time;
  BlockId get target;
  BlockId get chainWork;
  int get nonce;
  int get height;
  int get transactionCount;

  Map<String, dynamic> toJson();
  int deltaWork(BlockHeader x);
  int hashRate(BlockHeader X);
}

abstract class Block {
  BlockHeader get header;
  List<Transaction> get transactions;
  BlockId id();
}

class BlockMessage {
  BlockId id;
  Block block;
  BlockMessage(this.id, this.block);
}

class BlockHeaderMessage {
  BlockId id;
  BlockHeader header;
  BlockHeaderMessage(this.id, this.header);
}

CRUZ cruz = CRUZ();

List<Currency> currencies = <Currency>[cruz];
