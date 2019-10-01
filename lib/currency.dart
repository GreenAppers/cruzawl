// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

import "package:pointycastle/src/utils.dart";

import 'package:cruzawl/btc.dart';
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/http.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';

/// Interface [Wallet] interacts with, potentially supports multiple cryptos
abstract class Currency {
  const Currency();

  /// Called by [Wallet.fromFile] to load a wallet for an arbitrary [Currency]
  factory Currency.fromJson(String x) {
    switch (x) {
      case 'BTC':
        return btc;
      case 'CRUZ':
        return cruz;
      case 'ETH':
        return null;
      default:
        return null;
    }
  }

  /// Ticker for the currency. e.g. CRUZ.
  String get ticker;

  /// Name of the currency. e.g. cruzbit.
  String get name;

  /// URL for the currency.
  String get url;

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

  /// Returns number of coins issued at [height].
  int supply(int height) => null;

  /// Returns the expected block reward for the given [height].
  int blockCreationReward(int height) => null;

  /// Suggests a fee for [transaction].
  String suggestedFee(Transaction transaction) => null;

  /// Create a [PeerNetwork] instance for this currency.
  PeerNetwork createNetwork(
      {VoidCallback peerChanged,
      VoidCallback tipChanged,
      HttpClient httpClient});

  /// The [Block] with [Block.height] equal zero.
  Block genesisBlock();

  /// Derives the [Address] specified by [Wallet.seed] and [path].
  Address deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]);

  /// Creates a non-HD [Address] specified by [key].
  Address fromPrivateKey(PrivateKey key);

  /// Creates a watch-only [Address] specified by [key].
  Address fromPublicKey(PublicAddress key);

  /// Creates a watch-only [Address] specified by [address].
  Address fromPublicAddress(PublicAddress address);

  /// Unmarshals a JSON-encoded string to [Address].
  Address fromAddressJson(Map<String, dynamic> json);

  /// Unmarshals a JSON-encoded string to [PublicAddress].
  PublicAddress fromPublicAddressJson(String text);

  /// Unmarshals a JSON-encoded string to [PublicAddress].
  PublicAddress fromPublicKeyJson(String text);

  /// Unmarshals a JSON-encoded string to [PrivateKey].
  PrivateKey fromPrivateKeyJson(String text);

  /// Unmarshals a JSON-encoded string to [BlockId].
  BlockId fromBlockIdJson(String text, [bool pad = false]);

  /// Unmarshals a JSON-encoded string to [TransactionId].
  TransactionId fromTransactionIdJson(String text, [bool pad = false]);

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

  String get ticker => 'CRUZ';
  String get name => 'cruzbit';
  String get url => null;
  int get bip44CoinType => 0;
  int get coinbaseMaturity => 0;
  PublicAddress get nullAddress => null;

  PeerNetwork createNetwork(
          {VoidCallback peerChanged,
          VoidCallback tipChanged,
          HttpClient httpClient}) =>
      null;
  Block genesisBlock() => null;
  Address deriveAddress(Uint8List seed, String path,
          [StringCallback debugPrint]) =>
      null;
  Address fromPrivateKey(PrivateKey key) => null;
  Address fromPublicKey(PublicAddress key) => null;
  Address fromPublicAddress(PublicAddress address) => null;
  Address fromAddressJson(Map<String, dynamic> json) => null;
  PublicAddress fromPublicAddressJson(String text) => null;
  PublicAddress fromPublicKeyJson(String text) => null;
  PrivateKey fromPrivateKeyJson(String text) => null;
  BlockId fromBlockIdJson(String text, [bool pad = false]) => null;
  TransactionId fromTransactionIdJson(String text, [bool pad = false]) => null;
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

  /// Derive the [PublicAddress] associated with this [PrivateKey].
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
  PublicAddress get publicAddress;

  /// The public key (if any) associated with this [Address].
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

/// Interface representing the sender of currency.
abstract class TransactionInput {
  // Amount of currency from this input.
  int get value;

  /// Address of sender.
  PublicAddress get address;

  /// Describes the sender.
  String get fromText;

  /// Returns true if this [TransactionInput] rewards mining.
  bool isCoinbase();
}

/// Interface representing the recipient of currency.
abstract class TransactionOutput {
  // Amount of currency to this output.
  int get value;

  /// Address of recipient.
  PublicAddress get address;

  /// Describes the recipient.
  String get toText => address.toJson();
}

/// Interface for a transaction transfering value between parties.
abstract class Transaction {
  /// [BlockHeader.height] where this transaction appears in the blockchain.
  /// Zero for uncomfirmed transactions.
  int height = 0;

  /// Time this transaction was created for CRUZ or epoch.
  DateTime get dateTime;

  /// De-dupes similar transactions for CRUZ or null.
  int get nonce;

  /// The [PublicAddress] this transaction transfers value from.
  List<TransactionInput> get inputs;

  /// The [PublicAddress] this transaction transfers value to.
  List<TransactionOutput> get outputs;

  /// Amount of value this transaction transfers.
  num get amount;

  /// The handling fee paid to the [PeerNetwork] for this transaction.
  num get fee;

  /// Optional memo attachment.
  String get memo;

  /// Optional height delay for including this transaction.
  int get matures;

  /// Optional height expiry for including this transaction.
  int get expires;

  /// Marshals this transaction as a JSON-encoded string.
  Map<String, dynamic> toJson();

  /// Computes an ID for this transaction.
  TransactionId id();

  /// Returns true if the transaction cannot be mined at the given height
  bool isExpired(int height) => (expires ?? 0) == 0 ? false : expires < height;

  /// Verifies this transaction's signature.
  bool verify();

  /// Block height after which this transaction can be spent.
  int get maturity => max(matures ?? 0, isCoinbase() ? height + 100 : 0);

  /// Returns true if this transaction rewards mining.
  bool isCoinbase() =>
      inputs == null || (inputs.length == 1 && inputs[0].isCoinbase());

  /// Sorts by [time] and tie-break so only equivalent [Transaction] compare equal.
  static int timeCompare(Transaction a, Transaction b) {
    if (a.dateTime.isBefore(b.dateTime)) return 1;
    if (a.dateTime.isAfter(b.dateTime)) return -1;
    return a.id().toJson().compareTo(b.id().toJson());
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
  /// Marshals this [BlockId] as a JSON-encoded string.
  String toJson();

  /// Decode this [BlockId] to a [BigInt].
  BigInt toBigInt();
}

/// Interface for block header with [BlockHeader.nonce] varied by [PeerNetwork] miners
abstract class BlockHeader {
  /// ID of the previous block in this chain.
  BlockId get previous;

  /// Checksum of all the transaction in this block.
  TransactionId get hashRoot;

  /// Time this block was mined.
  DateTime get dateTime;

  /// Threshold new [Block] must hash under for Proof of Work.
  BlockId get target;

  /// Total cumulative chain work.
  /// [blockWork(genesisBock)] + [deltaWork(genesisBlock)].
  BlockId get chainWork;

  /// Parameter varied by miners for Proof of Work.
  int get nonce;

  /// The [BlockHeader.height] of [previous] plus one.
  int get height;

  /// The number of transactions in this block.
  /// Strictly positive if coinbase transactions are required.
  int get transactionCount;

  /// Marshals this [BlockHeader] as a JSON-encoded string.
  Map<String, dynamic> toJson();

  /// Computes an ID for this block.
  BlockId id();

  /// Expected number of random hashes before mining this block.
  BigInt blockWork() {
    BigInt twoTo256 = decodeBigInt(Uint8List(33)..[0] = 1);
    return twoTo256 ~/ (target.toBigInt() + BigInt.from(1));
  }

  /// Difference in work between [x] and this block.
  BigInt deltaWork(BlockHeader x) =>
      chainWork.toBigInt() - x.chainWork.toBigInt();

  /// Difference in time between [x] and this block.
  Duration deltaTime(BlockHeader x) => dateTime.difference(x.dateTime);

  /// Expected hashes per second from [x] to this block.
  int hashRate(BlockHeader x) {
    int dt = deltaTime(x).inSeconds;
    return dt == 0 ? 0 : (deltaWork(x) ~/ BigInt.from(dt)).toInt();
  }

  /// Compare [BlockHeader.height] of [a] and [b].
  static int compareHeight(dynamic a, dynamic b) => b.height - a.height;
}

/// Interface for [Block] that the [PeerNetwork] chains
abstract class Block {
  /// Data used to determine block validity and place in the block chain.
  BlockHeader get header;

  /// The transactions in this block.
  List<Transaction> get transactions;

  /// Computes an ID for this block.
  BlockId id();

  /// Compute a hash list root of all transaction hashes.
  TransactionId computeHashRoot();
}

const LoadingCurrency loadingCurrency = LoadingCurrency();

const CRUZ cruz = CRUZ();

const BTC btc = BTC();

const List<Currency> currencies = <Currency>[cruz, btc];
