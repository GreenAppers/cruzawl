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

  /// The only dynamic property.
  PeerNetwork get network;

  /// Name of the currency. e.g. CRUZ.
  String get ticker;

  /// Coin ID for HD wallets. e.g. 831.
  /// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
  int get bip44CoinType;

  /// Number of blocks until mining rewards are spendable.
  int get coinbaseMaturity;

  /// Address with the value of zero.
  PublicAddress get nullAddress;

  /// Marshals [Currency] as a JSON-encoded string.
  String toJson() => ticker;

  /// Format [Currency] denominated value [v].
  /// e.g. For [v] = 1000000 (Satoshis) return '.01' (BTC).
  String format(num v) => v.toString();

  /// Parse [Ticker] value [v] into discerete [Currency] units.
  /// e.g. For [v] = '.01' (BTC) return 1000000 (Satoshis).
  num parse(String v) => num.tryParse(v) ?? 0;

  /// Returns [DateTime] for [BlockHeader.time] and [Transaction.time].
  DateTime parseTime(int time) =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000);

  /// Suggests a fee for [transaction].
  String suggestedFee(Transaction transaction) => null;

  /// The [BlockId] with [Block.height] equal zero.
  String genesisBlockId();

  /// Derives the [Address] specified by [Wallet.seed] and [path].
  Address deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]);

  /// Creates a non-HD [Address] specified by [key].
  Address fromPrivateKey(PrivateKey key);

  /// Creates a watch-only [Address] specified by [key].
  Address fromPublicKey(PublicAddress key);

  /// Unmarshals a JSON-encoded string to [Address].
  Address fromAddressJson(Map<String, dynamic> json);

  /// Unmarshals a JSON-encoded string to [PublicAddress].
  PublicAddress fromPublicAddressJson(String text);

  /// Unmarshals a JSON-encoded string to [PrivateKey].
  PrivateKey fromPrivateKeyJson(String text);

  /// Unmarshals a JSON-encoded string to [TransactionId].
  TransactionId fromTransactionIdJson(String text);

  /// Unmarshals a JSON-encoded string to [Transaction].
  Transaction fromTransactionJson(Map<String, dynamic> json);

  /// Create signed [Transcation] using the [Address.privateKey] for [from].
  /// Transfers [amount] to [to] once if transmitted to the [PeerNetwork].
  Transaction signedTransaction(Address from, PublicAddress to, num amount,
      num fee, String memo, int height,
      {int matures, int expires});
}

/// Placeholder [Currency] during [Wallet] loading
class LoadingCurrency extends Currency {
  const LoadingCurrency();

  PeerNetwork get network => null;
  String get ticker => 'CRUZ';
  int get bip44CoinType => 0;
  int get coinbaseMaturity => 0;
  PublicAddress get nullAddress => null;

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

  /// Retrieve the [PublicAddress] associted with this [PrivateKey].
  PublicAddress getPublicKey();

  /// Derive the [PublicAddress] associted with this [PrivateKey].
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
  /// Display name for this [Address].
  String name;

  /// [AddressState] tracks used and removed [Adddress].
  AddressState state = AddressState.reserve;

  /// ID of the [Account] this [Address] belongs to.
  int accountId;

  /// The chain index (if any) used to derive this [Address].
  int chainIndex;

  /// Lowest [Block.height] involving this [Address].
  int earliestSeen;

  /// Highest [Block.height] involving this [Address].
  int latestSeen;

  /// Spendable balance for this [Address].
  num balance = 0;

  /// Maturing balance height for this address.
  int maturesHeight = 0;

  /// Maturing balance for this address.
  num maturesBalance = 0;

  /// Holds [balance] update during [PeerNetwork] synchronization.
  num newBalance;

  /// Holds [maturesBalance] update during [PeerNetwork] synchronization.
  num newMaturesBalance;

  /// Iterator for loading more [Transaction] involving [Address].
  TransactionIterator loadIterator;

  /// The [PublicAddress] defines this [Address].
  PublicAddress get publicKey;

  /// The [PrivateKey] (if any) assocaited with [publicKey].
  PrivateKey get privateKey;

  /// The chain code (if any) associated with [privateKey].
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

/// Interface for e.g. SHA3-256 of [Transaction] data
abstract class TransactionId {
  /// Marshals this transaction ID as a JSON-encoded string.
  String toJson();
}

/// Interface for a transaction transfering value between parties.
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
