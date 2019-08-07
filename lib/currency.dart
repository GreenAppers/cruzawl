// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';

/// Interface [Wallet] interacts with, potentially supports multiple cryptos
abstract class Currency {
  const Currency();

  /// Called by [Wallet.fromFile] to load a wallet for an arbitrary [Currency]
  factory Currency.fromJson(String x) {
    switch (x) {
      case 'CRUZ':
        return cruz;
      default:
        return null;
    }
  }

  /// The only dynamic property
  PeerNetwork get network;

  // Constants
  String get ticker;
  int get bip44CoinType;
  int get coinbaseMaturity;
  PublicAddress get nullAddress;

  // Constant functions
  String toJson() => ticker;
  String format(num v) => v.toString();
  num parse(String v) => num.tryParse(v) ?? 0;
  DateTime parseTime(int time) =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000);
  String suggestedFee(Transaction t) => null;

  // Currency API
  String genesisBlockId();
  Address deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]);
  Address fromPrivateKey(PrivateKey key);
  Address fromPublicKey(PublicAddress key);
  Address fromAddressJson(Map<String, dynamic> json);
  PublicAddress fromPublicAddressJson(String text);
  PrivateKey fromPrivateKeyJson(String text);
  TransactionId fromTransactionIdJson(String text);
  Transaction fromTransactionJson(Map<String, dynamic> json);
  Transaction signedTransaction(Address from, PublicAddress to, num amount,
      num fee, String memo, int height,
      {int matures, int expires});
}

/// Placeholder [Currency] during [Wallet] loading
class LoadingCurrency extends Currency {
  const LoadingCurrency();

  /// Null network.
  PeerNetwork get network => null;

  // Constants
  String get ticker => 'CRUZ';
  int get bip44CoinType => 0;
  int get coinbaseMaturity => 0;
  PublicAddress get nullAddress => null;

  // Null Currency API
  String genesisBlockId() => null;
  Address deriveAddress(Uint8List seed, String path,
          [StringCallback debugPrint]) =>
      null;
  Address fromPrivateKey(PrivateKey key) => null;
  Address fromPublicKey(PublicAddress key) => null;
  Address fromAddressJson(Map<String, dynamic> json) => null;
  PublicAddress fromPublicAddressJson(String text) => null;
  PrivateKey fromPrivateKeyJson(String text) => null;
  TransactionId fromTransactionIdJson(String text) => null;
  Transaction fromTransactionJson(Map<String, dynamic> json) => null;
  Transaction signedTransaction(Address from, PublicAddress to, num amount,
          num fee, String memo, int height,
          {int matures, int expires}) =>
      null;
}

/// Interface for e.g. Ed25519 public key
abstract class PublicAddress {
  /// Marshals this address as a JSON-encoded string.
  String toJson();
}

/// Interface for e.g. Ed25519 private key
abstract class PrivateKey {
  /// Marshals this key as a JSON-encoded string.
  String toJson();
  PublicAddress getPublicKey();
  PublicAddress derivePublicKey();
}

/// Interface for e.g. Ed25519 signature
abstract class Signature {
  /// Marshals this signature as a JSON-encoded string.
  String toJson();
}

/// Interface for e.g. SLIP-0010 chain code
abstract class ChainCode {
  /// Marshals this chain code as a JSON-encoded string.
  String toJson();
}

enum AddressState { reserve, open, used, remove }

/// Interface for element that [Wallet] contains
abstract class Address {
  String name;
  AddressState state = AddressState.reserve;
  int accountId, chainIndex, earliestSeen, latestSeen;
  num balance = 0;

  // JSON ignore
  int maturesHeight = 0, loadedHeight, loadedIndex;
  num maturesBalance = 0, newBalance, newMaturesBalance;

  // Accessors
  PublicAddress get publicKey;
  PrivateKey get privateKey;
  ChainCode get chainCode;

  /// Marshals [Address] as a JSON-encoded string.
  Map<String, dynamic> toJson();

  /// Verifies the integrity of this [Address]
  bool verify();

  /// Track the earliest and latest [height] each [Address] has been seen
  void updateSeenHeight(int height) {
    if (latestSeen == null || height > latestSeen) latestSeen = height;
    if (earliestSeen == null || height < earliestSeen) earliestSeen = height;
  }

  /// An HD wallet [Address] is defined by an [accountId], [chainIndex] pair
  static int compareIndex(dynamic a, dynamic b) {
    int accountDiff = a.accountId - b.accountId;
    return accountDiff != 0 ? accountDiff : a.chainIndex - b.chainIndex;
  }

  /// Sort by [balance] and tie-break so only equivalent [Address] compare equal
  static int compareBalance(dynamic a, dynamic b) {
    int balanceDiff = b.balance - a.balance;
    return balanceDiff != 0 ? balanceDiff : compareIndex(a, b);
  }

  /// Find single [Address] with greatest [balance]
  static Address reduceBalance(Address a, Address b) =>
      b.balance > a.balance ? b : a;
}

/// e.g. SHA3-256 of [Transaction] data
abstract class TransactionId {
  /// Marshals this transaction ID as a JSON-encoded string.
  String toJson();
}

abstract class Transaction {
  /// [BlockHeader.height] where this transaction appears in the blockchain.
  /// Zero for uncomfirmed transactions.
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

  /// Marshals this transaction as a JSON-encoded string.
  Map<String, dynamic> toJson();

  /// Computes an ID for this transaction.
  TransactionId id();

  /// Verifies this transaction's signature.
  bool verify();

  /// The JSON-encoded sender of this transaction.
  String get fromText => from.toJson();

  /// The JSON-encoded receiver of this transaction.
  String get toText => to.toJson();

  /// Block height after which this transaction can be spent.
  int get maturity => max(matures ?? 0, from != null ? 0 : height + 100);

  /// Sorts by [time] and tie-break so only equivalent [Transaction] compare equal.
  static int timeCompare(Transaction a, Transaction b) {
    int deltaT = -a.time + b.time;
    return deltaT != 0 ? deltaT : a.id().toJson().compareTo(b.id().toJson());
  }

  /// Sorts by [maturity] and tie-break so only equivalent [Transaction] compare equal.
  static int maturityCompare(Transaction a, Transaction b) {
    int deltaM = a.maturity - b.maturity;
    return deltaM != 0 ? deltaM : a.id().toJson().compareTo(b.id().toJson());
  }
}

typedef TransactionCallback = void Function(Transaction);

/// Interface for e.g. SHA3-256 of [BlockHeader] data
abstract class BlockId {
  Uint8List data;
  String toJson();
  BigInt toBigInt();
}

/// Interface for block header with [BlockHeader.nonce] varied by [PeerNetwork] miners
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
  BigInt blockWork();
  BigInt deltaWork(BlockHeader x);
  int deltaTime(BlockHeader x);
  int hashRate(BlockHeader x);

  static int compareHeight(dynamic a, dynamic b) => b.height - a.height;
}

/// Interface for [Block] that the [PeerNetwork] chains
abstract class Block {
  BlockHeader get header;
  List<Transaction> get transactions;
  BlockId id();
}

CRUZ cruz = CRUZ();

List<Currency> currencies = <Currency>[cruz];
