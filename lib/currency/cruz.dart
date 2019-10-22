// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import "package:convert/convert.dart";
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import "package:pointycastle/digests/sha256.dart";
import "package:pointycastle/src/utils.dart";
import 'package:tweetnacl/tweetnacl.dart' as tweetnacl;

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/network/http.dart';
import 'package:cruzawl/network/socket.dart';
import 'package:cruzawl/network/websocket.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sha3.dart';
import 'package:cruzawl/util.dart';

part 'cruz.g.dart';

/// cruzbit: A simple decentralized peer-to-peer ledger implementation.
/// https://github.com/cruzbit/cruzbit
class CRUZ extends Currency {
  const CRUZ();

  /// 1 week in blocks.
  /// Reference: https://github.com/cruzbit/cruzbit/blob/master/constants.go#L42
  static const int blocksUntilNewSeries = 1008;

  /// Same ratio of cruzbits to CRUZ as Satoshis to Bitcoin.
  /// Reference: https://github.com/cruzbit/cruzbit/blob/master/constants.go#L10
  static const int cruzbitsPerCruz = 100000000;

  /// Initial CRUZ reward for mining a block.
  static const int initialCoinbaseReward = 50;

  /// 4 years in blocks.
  static const int blocksUntilRewardHalving = 210000;

  /// Ticker symbol.  e.g. the CRUZ in https://qtrade.io/market/CRUZ_BTC
  @override
  String get ticker => 'CRUZ';

  /// Official name.
  @override
  String get name => 'cruzbit';

  /// Official homepage.
  @override
  String get url => 'https://cruzb.it/';

  /// The coin type used for HD wallets.
  /// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
  @override
  int get bip44CoinType => 831;

  /// Coinbase transactions mature after 100 blocks.
  /// Reference: https://github.com/cruzbit/cruzbit/blob/master/constants.go#L14
  @override
  int get coinbaseMaturity => 100;

  /// Format discrete cruzbit value [v] in fractional CRUZ representation.
  @override
  String format(num v) =>
      v != null ? (v / cruzbitsPerCruz).toStringAsFixed(2) : '0';

  /// Parse fractional CRUZ value [v] into discrete cruzbits.
  @override
  num parse(String v) {
    num x = num.tryParse(v);
    return x != null ? (x * cruzbitsPerCruz).floor() : 0;
  }

  /// Returns number of CRUZ issued at [height].
  @override
  int supply(int blocks) {
    int supply = 0, reward = initialCoinbaseReward * cruzbitsPerCruz;
    while (blocks > 0) {
      if (blocks > blocksUntilRewardHalving) {
        supply += (reward * blocksUntilRewardHalving);
        blocks -= blocksUntilRewardHalving;
        reward = reward ~/ 2;
      } else {
        supply += (reward * blocks);
        blocks = 0;
      }
    }
    return supply ~/ cruzbitsPerCruz;
  }

  /// Computes the expected block reward for the given [height].
  @override
  int blockCreationReward(int height) {
    int halvings = height ~/ blocksUntilRewardHalving;
    return halvings >= 64
        ? 0
        : (initialCoinbaseReward * cruzbitsPerCruz) >> halvings;
  }

  /// 0.01
  /// Reference: https://github.com/cruzbit/cruzbit/blob/master/constants.go#L70
  @override
  String suggestedFee(Transaction t) => '0.01';

  /// Address with the value of zero.
  @override
  PublicAddress get nullAddress => CruzPublicKey(Uint8List(32));

  /// Create a cruzbit.1 [PeerNetwork] instance.
  @override
  CruzPeerNetwork createNetwork(
          {VoidCallback peerChanged,
          VoidCallback tipChanged,
          HttpClient httpClient,
          String userAgent}) =>
      CruzPeerNetwork(peerChanged, tipChanged);

  /// The first [Block] in the chain. e.g. https://www.cruzbase.com/#/height/0
  @override
  CruzBlock genesisBlock() => CruzBlock.fromJson(jsonDecode(genesisBlockJson));

  /// SLIP-0010: Universal private key derivation from master private key.
  @override
  CruzAddress deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]) {
    KeyData data = ED25519_HD_KEY.derivePath(path, hex.encode(seed));
    Uint8List publicKey = ED25519_HD_KEY.getBublickKey(data.key, false);
    if (debugPrint != null) {
      debugPrint('deriveAddress($path) = ${base64.encode(publicKey)}');
    }
    return CruzAddress(
        CruzPublicKey(publicKey),
        CruzPrivateKey(Uint8List.fromList(data.key + publicKey)),
        CruzChainCode(data.chainCode));
  }

  /// Cruz addresses are public keys.
  @override
  CruzAddress fromPublicAddress(PublicAddress addr) => fromPublicKey(addr);

  /// For Watch-only wallets.
  @override
  CruzAddress fromPublicKey(PublicAddress addr) {
    CruzPublicKey key = CruzPublicKey.fromJson(addr.toJson());
    return CruzAddress.fromPublicKey(key);
  }

  /// For non-HD wallets.
  @override
  CruzAddress fromPrivateKey(PrivateKey key) => CruzAddress.fromPrivateKey(key);

  /// For loading wallet from storage.
  @override
  CruzAddress fromAddressJson(Map<String, dynamic> json) =>
      CruzAddress.fromJson(json);

  /// CRUZ addresses are public keys.
  @override
  CruzPublicKey fromPublicAddressJson(String text) => fromPublicKeyJson(text);

  /// Parse CRUZ public key.
  @override
  CruzPublicKey fromPublicKeyJson(String text) {
    try {
      Uint8List data = base64.decode(text);
      if (data.length != CruzPublicKey.size) return null;
      return CruzPublicKey(data);
    } catch (_) {
      return null;
    }
  }

  /// Parse CRUZ private key.
  @override
  CruzPrivateKey fromPrivateKeyJson(String text) {
    try {
      return CruzPrivateKey.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse CRUZ block id.
  @override
  CruzBlockId fromBlockIdJson(String text, [bool pad = false]) {
    try {
      if (pad) {
        return CruzBlockId.fromString(text);
      } else {
        return CruzBlockId.fromJson(text);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parse CRUZ transaction id.
  @override
  CruzTransactionId fromTransactionIdJson(String text, [bool pad = false]) {
    try {
      if (pad) {
        return CruzTransactionId.fromString(text);
      } else {
        return CruzTransactionId.fromJson(text);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parse CRUZ transaction.
  @override
  CruzTransaction fromTransactionJson(Map<String, dynamic> json) =>
      CruzTransaction.fromJson(json);

  /// Creates signed CRUZ transaction.
  @override
  CruzTransaction signedTransaction(Address fromInput, PublicAddress toInput,
      num amount, num fee, String memo, int height,
      {int matures, int expires}) {
    if (!(fromInput is CruzAddress)) throw FormatException();
    if (!(toInput is CruzPublicKey)) throw FormatException();
    CruzAddress from = fromInput;
    CruzPublicKey to = toInput;
    return CruzTransaction(from.publicKey, to, amount, fee, memo,
        matures: matures, expires: expires, seriesForHeight: height)
      ..sign(from.privateKey);
  }
}

/// Ed25519 public key, 32 bytes.
@immutable
class CruzPublicKey extends PublicAddress {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  CruzPublicKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a base64-encoded string to [CruzPublicKey].
  CruzPublicKey.fromJson(String x) : this(base64.decode(x));

  /// Marshals [CruzPublicKey] as a base64-encoded string.
  @override
  String toJson() => base64.encode(data);
}

/// Ed25519 private key (pair), 64 bytes.
@immutable
class CruzPrivateKey extends PrivateKey {
  final Uint8List data;
  static const int size = 64;

  /// Fully specified constructor used by JSON deserializer.
  CruzPrivateKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a base64-encoded string to [CruzPrivateKey].
  CruzPrivateKey.fromJson(String x) : this(base64.decode(x));

  /// Marshals [CruzPrivateKey] as a base64-encoded string.
  @override
  String toJson() => base64.encode(data);

  /// The second half of an Ed25519 private key is the public key.
  CruzPublicKey getPublicKey() =>
      CruzPublicKey(data.buffer.asUint8List(size - CruzPublicKey.size));

  /// Used to verify the key pair.
  CruzPublicKey derivePublicKey() => CruzPublicKey(
      tweetnacl.Signature.keyPair_fromSeed(data.buffer.asUint8List(0, 32))
          .publicKey);
}

/// Ed25519 signature, 64 bytes.
@immutable
class CruzSignature extends Signature {
  final Uint8List data;
  static const int size = 64;

  /// Fully specified constructor used by JSON deserializer.
  CruzSignature(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a base64-encoded string to [CruzSignature].
  CruzSignature.fromJson(String x) : this(base64.decode(x));

  /// Marshals [CruzSignature] as a base64-encoded string.
  String toJson() => base64.encode(data);
}

/// SLIP-0010 chain code.
@immutable
class CruzChainCode extends ChainCode {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  CruzChainCode(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a base64-encoded string to [CruzChainCode].
  CruzChainCode.fromJson(String x) : this(base64.decode(x));

  /// Marshals [CruzChainCode] as a base64-encoded string.
  @override
  String toJson() => base64.encode(data);
}

/// SHA3-256 of the CRUZ transaction JSON.
@immutable
class CruzTransactionId extends TransactionId {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  CruzTransactionId(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Computes the hash of [transactionJson].
  CruzTransactionId.compute(String transactionJson)
      : data = SHA3Digest(256, false).process(utf8.encode(transactionJson));

  /// Unmarshals a hex string to [CruzTransactionId].
  CruzTransactionId.fromJson(String x) : this(hex.decode(x));

  /// Unmarshals a hex string (with leading zeros optionally truncated) to [CruzTransactionId].
  CruzTransactionId.fromString(String x)
      : this(zeroPadUint8List(hex.decode(zeroPadOddLengthString(x)), size));

  /// Marshals [CruzTransactionId] as a hex string.
  @override
  String toJson() => hex.encode(data);
}

/// Shim [TransactionInput] for CRUZ which has only a single input and output.
class CruzTransactionInput extends TransactionInput {
  @override
  CruzPublicKey address;

  @override
  int value;

  CruzTransactionInput(this.address, this.value);

  // The base64-encoded sender of this transaction, or 'cruzbase' if no sender.
  @override
  String get fromText => isCoinbase ? 'cruzbase' : address.toJson();

  /// Returns true if the transaction is a coinbase. A coinbase is the first
  /// transaction in every block used to reward the miner for mining the block.
  @override
  bool get isCoinbase => address == null;
}

/// Shim [TransactionOutput] for CRUZ which has only a single input and output.
class CruzTransactionOutput extends TransactionOutput {
  @override
  CruzPublicKey address;

  @override
  int value;

  CruzTransactionOutput(this.address, this.value);
}

/// A ledger transaction representation. It transfers value from one public key to another.
/// Reference: https://github.com/cruzbit/cruzbit/blob/master/transaction.go
@JsonSerializable(includeIfNull: false)
class CruzTransaction extends Transaction {
  // Unix time
  int time;

  @override
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(time * 1000);

  /// Collision prevention. Pseudorandom. Not used for crypto.
  @override
  int nonce;

  /// Public key this transaction transfers value from.
  CruzPublicKey from;

  /// Public key this transaction transfers value to.
  CruzPublicKey to;

  /// Amount of value this transaction transfers in cruzbits.
  @override
  int amount;

  /// The handling fee paid to the [PeerNetwork] for this transaction.
  @override
  int fee;

  /// Max 100 characters.
  @override
  String memo;

  /// Block height. If set transaction can't be mined before.
  @override
  int matures;

  /// Block height. If set transaction can't be mined after.
  @override
  int expires;

  /// Increments roughly once a week to allow for pruning history.
  int series;

  /// The signature of this transaction.
  CruzSignature signature;

  /// Used by [Wallet].  Not marshaled.
  @JsonKey(ignore: true)
  int height = 0;

  @override
  bool get isCoinbase => from == null;

  @override
  @JsonKey(ignore: true)
  CruzTransactionId hash;

  @override
  List<CruzTransactionInput> get inputs =>
      [CruzTransactionInput(from, amount + (fee ?? 0))];

  @override
  List<CruzTransactionOutput> get outputs =>
      [CruzTransactionOutput(to, amount)];

  /// Creates an arbitrary unsigned [CruzTransaction].
  CruzTransaction(this.from, this.to, this.amount, this.fee, this.memo,
      {this.matures, this.expires, this.series, int seriesForHeight})
      : time = DateTime.now().millisecondsSinceEpoch ~/ 1000,
        nonce = Random.secure().nextInt(2147483647) {
    if (series == null) {
      series = computeTransactionSeries(from == null, seriesForHeight);
    }
    if (memo != null && memo.isEmpty) memo = null;
  }

  /// Copies transaction [x] minus the [signature]
  CruzTransaction.withoutSignature(CruzTransaction x)
      : time = x.time,
        nonce = x.nonce,
        from = x.from,
        to = x.to,
        amount = x.amount,
        fee = x.fee,
        memo = x.memo,
        matures = x.matures,
        expires = x.expires,
        series = x.series;

  /// Unmarshals a JSON-encoded string to [CruzTransaction].
  factory CruzTransaction.fromJson(Map<String, dynamic> json) =>
      _$CruzTransactionFromJson(json);

  /// Marshals [CruzTransaction] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => signedJson();

  /// Equivalent to [toJson].
  Map<String, dynamic> signedJson() => _$CruzTransactionToJson(this);

  /// Marshals [CruzTransaction] sans [signature] as a JSON-encoded string.
  Map<String, dynamic> unsignedJson() => signature == null
      ? _$CruzTransactionToJson(this)
      : _$CruzTransactionToJson(CruzTransaction.withoutSignature(this));

  /// Computes an ID for this transaction.
  @override
  CruzTransactionId id() =>
      CruzTransactionId.compute(jsonEncode(unsignedJson()));

  /// Signs this transaction.
  void sign(CruzPrivateKey key) =>
      signature = CruzSignature(tweetnacl.Signature(null, key.data)
          .sign(id().data)
          .buffer
          .asUint8List(0, 64));

  /// Verify only that the transaction is properly signed.
  @override
  bool verify() => signature == null
      ? false
      : tweetnacl.Signature(from.data, null)
          .detached_verify(id().data, signature.data);

  /// Computes the series to use for a new transaction.
  /// Reference: https://github.com/cruzbit/cruzbit/blob/master/transaction.go#L143
  static int computeTransactionSeries(bool isCoinbase, int height) {
    if (isCoinbase) {
      /// coinbases start using the new series right on time
      return height ~/ CRUZ.blocksUntilNewSeries + 1;
    }

    /// otherwise don't start using a new series until 100 blocks in to mitigate
    /// potential reorg issues right around the switchover
    return (height - 100) ~/ CRUZ.blocksUntilNewSeries + 1;
  }
}

/// CRUZ implementation of the [Wallet] entry [Address] abstraction.
@JsonSerializable(includeIfNull: false)
class CruzAddress extends Address {
  /// In cruzbit public keys are the addresses.
  @override
  PublicAddress get publicAddress => publicKey;

  /// The public key of this [CruzAddress].
  CruzPublicKey publicKey;

  /// The private key for this address, if not watch-only.
  @override
  CruzPrivateKey privateKey;

  /// The chain code for this address, if HD derived.
  @override
  CruzChainCode chainCode;

  /// Maturing balance for this address.
  @JsonKey(ignore: true)
  num maturesBalance = 0;

  /// Maturing balance height for this address.
  @JsonKey(ignore: true)
  int maturesHeight = 0;

  /// Holds [balance] update during [PeerNetwork] synchronization.
  @JsonKey(ignore: true)
  num newBalance;

  /// Holds [maturesBalance] update during [PeerNetwork] synchronization.
  @JsonKey(ignore: true)
  num newMaturesBalance;

  /// Iterator for loading more [Transaction] involving [Address].
  @JsonKey(ignore: true)
  TransactionIterator loadIterator;

  /// Fully specified constructor used by JSON deserializer.
  CruzAddress(this.publicKey, this.privateKey, this.chainCode) {
    if (publicKey == null ||
        (privateKey != null &&
            !equalUint8List(publicKey.data, privateKey.getPublicKey().data))) {
      throw FormatException();
    }
  }

  /// Element of watch-only [Wallet].
  CruzAddress.fromPublicKey(this.publicKey);

  /// Element of non-HD [Wallet].
  CruzAddress.fromPrivateKey(this.privateKey) {
    publicKey = privateKey.derivePublicKey();
  }

  /// Element of HD [Wallet].
  CruzAddress.fromSeed(Uint8List seed) {
    tweetnacl.KeyPair pair = tweetnacl.Signature.keyPair_fromSeed(seed);
    publicKey = CruzPublicKey(pair.publicKey);
    privateKey = CruzPrivateKey(pair.secretKey);
  }

  /// Generate a random [CruzAddress]. Not used by [Wallet].
  CruzAddress.generateRandom()
      : this.fromSeed(SHA256Digest().process(randBytes(32)));

  /// Unmarshals a JSON-encoded string to [CruzAddress].
  factory CruzAddress.fromJson(Map<String, dynamic> json) =>
      _$CruzAddressFromJson(json);

  /// Marshals [CruzAddress] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$CruzAddressToJson(this);

  /// Verifies [privateKey] produces [publicKey].
  bool verify() =>
      privateKey != null &&
      equalUint8List(publicKey.data, privateKey.derivePublicKey().data) &&
      equalUint8List(publicKey.data, privateKey.getPublicKey().data);
}

/// Unique identifier for [Block].
/// e.g. the SHA3-256 of [CruzBlockHeader] JSON.
@immutable
class CruzBlockId extends BlockId {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  CruzBlockId(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Computes the hash of [blockHeaderJson].
  CruzBlockId.compute(String blockHeaderJson)
      : data = SHA3Digest(256, false).process(utf8.encode(blockHeaderJson));

  /// Unmarshals hex string to [CruzBlockId].
  CruzBlockId.fromJson(String x) : this(hex.decode(x));

  /// Unmarshals hex string (with leading zeros optionally truncated) to [CruzBlockId].
  CruzBlockId.fromString(String x)
      : this(zeroPadUint8List(hex.decode(zeroPadOddLengthString(x)), size));

  /// Marshals [CruzBlockId] as a hex string.
  @override
  String toJson() => hex.encode(data);

  /// Decodes a [BigInt] representation.
  @override
  BigInt toBigInt() => decodeBigInt(data);
}

/// List of [CruzBlockId]
@JsonSerializable()
class CruzBlockIds {
  List<CruzBlockId> block_ids;
  CruzBlockIds();

  /// Unmarshals a JSON-encoded string to [CruzBlockIds].
  factory CruzBlockIds.fromJson(Map<String, dynamic> json) =>
      _$CruzBlockIdsFromJson(json);

  /// Marshals [CruzBlockIds] as a JSON-encoded string.
  Map<String, dynamic> toJson() => _$CruzBlockIdsToJson(this);
}

/// Data used to determine block validity and place in the block chain.
/// Reference: https://github.com/cruzbit/cruzbit/blob/master/block.go
@JsonSerializable(includeIfNull: false)
class CruzBlockHeader extends BlockHeader {
  /// ID of the previous block in this chain.
  @override
  CruzBlockId previous;

  /// Hash of all the transactions in this block.
  @JsonKey(name: 'hash_list_root')
  CruzTransactionId hashRoot;

  /// Unix time.
  int time;

  @override
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(time * 1000);

  /// Threshold new [CruzBlock] must hash under for Proof of Work.
  @override
  CruzBlockId target;

  /// Total cumulative chain work.
  /// [blockWork(CRUZ.genesisBock())] + [deltaWork(genesisBlock)].
  @JsonKey(name: 'chain_work')
  CruzBlockId chainWork;

  /// Parameter varied by miners for Proof of Work.
  int nonce;

  @override
  BigInt get nonceValue => BigInt.from(nonce);

  /// Height is eventually unique.
  @override
  int height;

  /// The number of transactions in this block.
  @JsonKey(name: 'transaction_count')
  int transactionCount;

  /// Default constructor used by JSON deserializer.
  CruzBlockHeader();

  /// Unmarshals a JSON-encoded string to [CruzBlockHeader].
  factory CruzBlockHeader.fromJson(Map<String, dynamic> json) =>
      _$CruzBlockHeaderFromJson(json);

  /// Marshals [CruzBlockHeader] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$CruzBlockHeaderToJson(this);

  /// Computes an ID for this block.
  @override
  CruzBlockId id() => CruzBlockId.compute(jsonEncode(this));
}

/// Represents a block in the block chain. It has a header and a list of transactions.
/// As blocks are connected their transactions affect the underlying ledger.
/// Reference: https://github.com/cruzbit/cruzbit/blob/master/block.go
@JsonSerializable()
class CruzBlock extends Block {
  /// Header has [transactions] checksums and Proof of Work.
  @override
  CruzBlockHeader header;

  /// The list of [CruzTransaction] in this block of the ledger.
  @override
  List<CruzTransaction> transactions;

  /// Default constructor used by JSON deserializer.
  CruzBlock();

  /// Unmarshals a JSON-encoded string to [CruzBlock].
  factory CruzBlock.fromJson(Map<String, dynamic> json) =>
      _$CruzBlockFromJson(json);

  /// Marshals [CruzBlock] as a JSON-encoded string.
  Map<String, dynamic> toJson() => _$CruzBlockToJson(this);

  /// Computes an ID for this block.
  @override
  CruzBlockId id() => header.id();

  /// Compute a hash list root of all transaction hashes.
  @override
  CruzTransactionId computeHashRoot() {
    SHA3Digest hasher = SHA3Digest(256, false);
    for (int i = 1; i < transactions.length; i++) {
      CruzTransactionId id = transactions[i].id();
      hasher.update(id.data, 0, id.data.length);
    }

    CruzTransactionId rootHashWithoutCoinbase =
        CruzTransactionId(Uint8List(CruzTransactionId.size));
    hasher.doFinal(rootHashWithoutCoinbase.data, 0);
    return addCoinbaseToHashListRoot(rootHashWithoutCoinbase);
  }

  /// Add the coinbase to the hash list root.
  CruzTransactionId addCoinbaseToHashListRoot(
      CruzTransactionId rootHashWithoutCoinbase) {
    SHA3Digest hasher = SHA3Digest(256, false);
    CruzTransactionId coinbase = transactions[0].id();
    hasher.update(coinbase.data, 0, coinbase.data.length);
    hasher.update(
        rootHashWithoutCoinbase.data, 0, rootHashWithoutCoinbase.data.length);

    CruzTransactionId hashListRoot =
        CruzTransactionId(Uint8List(CruzTransactionId.size));
    hasher.doFinal(hashListRoot.data, 0);
    return hashListRoot;
  }
}

/// The cruzbit.1 [PeerNetwork] implementing a distributed ledger.
class CruzPeerNetwork extends PeerNetwork {
  CruzPeerNetwork(VoidCallback peerChanged, VoidCallback tipChanged)
      : super(peerChanged, tipChanged);

  @override
  CRUZ get currency => cruz;

  /// Creates [Peer] ready to [Peer.connect()].
  @override
  Peer createPeerWithSpec(PeerPreference spec) =>
      CruzPeer(spec, parseUri(spec.url, cruz.genesisBlock().id().toJson()));

  /// Valid CRUZ URI: 'wallet.cruzbit.xyz', 'wallet:8832', 'wss://wallet:8832'.
  String parseUri(String uriText, String genesisId) {
    if (!Uri.parse(uriText).hasScheme) uriText = 'wss://' + uriText;
    Uri uri = Uri.parse(uriText);
    Uri url = uri.replace(port: uri.hasPort ? uri.port : 8831);
    return url.toString() + '/' + genesisId;
  }
}

/// CRUZ implementation of the [PeerNetwork] entry [Peer] abstraction.
/// Reference: https://github.com/cruzbit/cruzbit/blob/master/protocol.go
class CruzPeer extends PersistentWebSocketClient with JsonResponseQueueMixin {
  /// The [CruzAddress] we're monitoring [CruzPeerNetwork] for.
  Map<String, TransactionCallback> addressFilter =
      Map<String, TransactionCallback>();

  @override

  /// [Block.height] of tip [CruzBlock] according to this peer.
  int get tipHeight => tip != null ? tip.height : 0;

  /// ID of tip [CruzBlock] according to this peer.
  @override
  CruzBlockId tipId;

  /// Header of tip [CruzBlock] according to this peer.
  CruzBlockHeader tip;

  /// The minimum [CruzTransaction.amount] for the [CruzPeerNetwork].
  @override
  num minAmount;

  /// The minimum [CruzTransaction.fee] for the [CruzPeerNetwork].
  @override
  num minFee;

  /// Forward [Peer] constructor.
  CruzPeer(PeerPreference spec, String address) : super(spec, address);

  /// Network lost. Clear [tip] and [tipId].
  @override
  void handleDisconnected() {
    addressFilter = Map<String, TransactionCallback>();
    tipId = null;
    tip = null;
  }

  /// Network connected. Request [tipId], [tip], [minAmount], and [minFee].
  @override
  void handleConnected() {
    // TipHeaderMessage is used to send a peer the header for the tip block in the block chain.
    // Type: "tip_header". It is sent in response to the empty "get_tip_header" message type.
    addJsonMessage(
      <String, dynamic>{
        'type': 'get_tip_header',
      },
      (Map<String, dynamic> response) {
        if (response == null) return;
        checkEquals('tip_header', response['type'], spec.debugPrint);
        tipId = CruzBlockId.fromJson(response['body']['block_id']);
        tip = CruzBlockHeader.fromJson(response['body']['header']);
        if (spec.debugPrint != null) {
          spec.debugPrint('initial blockHeight=${tip.height}');
        }
        setState(PeerState.ready);
        if (tipChanged != null) tipChanged();
      },
    );

    // TransactionRelayPolicyMessage is used to communicate this node's current settings for min fee and min amount.
    // Type: "transaction_relay_policy". Sent in response to the empty "get_transaction_relay_policy" message type.
    addJsonMessage(
      <String, dynamic>{
        'type': 'get_transaction_relay_policy',
      },
      (Map<String, dynamic> response) {
        if (response == null) return;
        checkEquals(
            'transaction_relay_policy', response['type'], spec.debugPrint);
        minAmount = response['body']['min_amount'];
        minFee = response['body']['min_fee'];
      },
    );
  }

  /// GetBalanceMessage requests a public key's balance.
  /// Type: "get_balance".
  @override
  Future<num> getBalance(PublicAddress address) {
    Completer<num> completer = Completer<num>();
    addJsonMessage(
      <String, dynamic>{
        'type': 'get_balance',
        'body': <String, dynamic>{
          'public_key': address.toJson(),
        },
      },
      (Map<String, dynamic> response) {
        if (response == null) {
          completer.complete(null);
          return;
        }
        checkEquals('balance', response['type'], spec.debugPrint);
        completer.complete(response['body']['balance']);
      },
    );
    return completer.future;
  }

  @override
  Future<TransactionIteratorResults> getTransactions(
      PublicAddress address, TransactionIterator iterator,
      {int limit = 20}) {
    if (iterator != null) {
      /// Increment this iterator.
      if (iterator.index == 0) {
        iterator.height--;
      } else {
        iterator.index--;
      }
    }
    return getPublicKeyTransactions(address,
        startHeight: iterator != null ? iterator.height : null,
        startIndex: iterator != null ? iterator.index : null,
        endHeight: iterator != null ? 0 : null,
        limit: limit);
  }

  /// GetPublicKeyTransactionsMessage requests transactions associated with a given public key over a given
  /// height range of the block chain.
  /// Type: "get_public_key_transactions".
  Future<TransactionIteratorResults> getPublicKeyTransactions(
      PublicAddress address,
      {int startHeight,
      int startIndex,
      int endHeight,
      int limit = 20}) {
    Completer<TransactionIteratorResults> completer =
        Completer<TransactionIteratorResults>();

    if (startHeight == null) {
      if (endHeight == null) {
        /// Get transactions in reverse order
        startHeight = tip.height;
        endHeight = 0;
      } else {
        startHeight = 0;
      }
    } else if (endHeight == null) {
      endHeight = tip.height + 1;
    }

    /// For forward iteration we need [endHeight] > [tip.height].
    /// Otherwise when [startHeight] == [endHeight] the direction is indistinguishable.
    bool reverseOrder = endHeight <= startHeight;

    Map<String, dynamic> body = <String, dynamic>{
      'public_key': address.toJson(),
      'start_height': startHeight,
      'end_height': endHeight,
      'limit': limit,
    };
    if (startIndex != null) body['start_index'] = startIndex;

    addJsonMessage(<String, dynamic>{
      'type': 'get_public_key_transactions',
      'body': body,
    }, (Map<String, dynamic> response) {
      if (response == null) {
        completer.complete(null);
        return;
      }
      checkEquals('public_key_transactions', response['type'], spec.debugPrint);
      List<dynamic> blocks = response['body']['filter_blocks'];
      TransactionIteratorResults ret = TransactionIteratorResults(
          response['body']['stop_height'],
          response['body']['stop_index'],
          List<Transaction>());

      /// If newIterator < oldIterator we're done.
      if (reverseOrder) {
        if (ret.height > startHeight ||
            (ret.height == startHeight &&
                startIndex != null &&
                ret.index > startIndex)) {
          ret.height = ret.index = 0;
        }
      } else {
        if (ret.height < startHeight ||
            (ret.height == startHeight &&
                startIndex != null &&
                ret.index < startIndex)) {
          ret.height = ret.index = 0;
        }
      }

      if (blocks == null) {
        completer.complete(ret);
      } else {
        for (var block in blocks) {
          List<Transaction> tx = CruzBlock.fromJson(block).transactions;
          for (Transaction x in tx) {
            x.height = block['header']['height'];
          }
          ret.transactions += tx;
        }
        completer.complete(ret);
      }
    });
    return completer.future;
  }

  /// PushTransactionMessage is used to push a newly processed unconfirmed transaction to peers.
  /// Type: "push_transaction".
  @override
  Future<TransactionId> putTransaction(Transaction transaction) {
    Completer<TransactionId> completer = Completer<TransactionId>();
    addJsonMessage(<String, dynamic>{
      'type': 'push_transaction',
      'body': <String, dynamic>{
        'transaction': transaction.toJson(),
      },
    }, (Map<String, dynamic> response) {
      if (response == null) {
        completer.complete(null);
        return;
      }
      checkEquals('push_transaction_result', response['type'], spec.debugPrint);
      Map<String, dynamic> result = response['body'];
      assert(result != null);
      if (result['error'] != null) {
        if (spec.debugPrint != null) {
          spec.debugPrint('putTransaction error: ' + result['error']);
        }
        completer.complete(null);
      } else {
        completer
            .complete(CruzTransactionId.fromJson(result['transaction_id']));
        handleNewTransaction(transaction);
      }
    });
    return completer.future;
  }

  /// FilterAddMessage is used to request the addition of the given public keys to the current filter.
  /// The filter is created if it's not set.
  /// Type: "filter_add".
  @override
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb) {
    addressFilter[address.toJson()] = transactionCb;
    Completer<bool> completer = Completer<bool>();
    addJsonMessage(
      <String, dynamic>{
        'type': 'filter_add',
        'body': <String, dynamic>{
          'public_keys': <String>[address.toJson()],
        },
      },
      (Map<String, dynamic> response) {
        if (response == null) {
          completer.complete(null);
          return;
        }
        checkEquals('filter_result', response['type'], spec.debugPrint);
        var body = response['body'];
        String error = body != null ? body['error'] : null;
        if (error != null && spec.debugPrint != null) {
          spec.debugPrint('filterAdd error: $error');
        }
        completer.complete(error == null);
      },
    );
    return completer.future;
  }

  /// FilterTransactionQueueMessage returns a pared down view of the unconfirmed transaction queue containing only
  /// transactions relevant to the peer given their filter.
  /// Type: "filter_transaction_queue".
  @override
  Future<bool> filterTransactionQueue() {
    Completer<bool> completer = Completer<bool>();
    addJsonMessage(
      <String, dynamic>{
        'type': 'get_filter_transaction_queue',
      },
      (Map<String, dynamic> response) {
        if (response == null) {
          completer.complete(null);
          return;
        }
        checkEquals(
            'filter_transaction_queue', response['type'], spec.debugPrint);
        var transactions = response['body']['transactions'];
        if (transactions != null) {
          for (var transaction in transactions) {
            handleNewTransaction(CruzTransaction.fromJson(transaction));
          }
        }
        completer.complete(true);
      },
    );
    return completer.future;
  }

  /// GetBlockHeaderMessage is used to request a block header.
  /// Type: "get_block_header".
  @override
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height}) {
    Completer<BlockHeaderMessage> completer = Completer<BlockHeaderMessage>();
    addJsonMessage(
      id != null
          ? <String, dynamic>{
              'type': 'get_block_header',
              'body': <String, dynamic>{
                'block_id': id.toJson(),
              },
            }
          : <String, dynamic>{
              'type': 'get_block_header_by_height',
              'body': <String, dynamic>{
                'height': height,
              },
            },
      (Map<String, dynamic> response) {
        if (response == null) {
          completer.complete(null);
          return;
        }
        checkEquals('block_header', response['type'], spec.debugPrint);
        var body = response['body'];
        var header = body != null ? body['header'] : null;
        completer.complete(BlockHeaderMessage(
            body != null ? CruzBlockId.fromJson(body['block_id']) : null,
            header != null ? CruzBlockHeader.fromJson(header) : null));
      },
    );
    return completer.future;
  }

  /// GetBlockMessage is used to request a block for download.
  /// Type: "get_block".
  @override
  Future<BlockMessage> getBlock({BlockId id, int height}) {
    Completer<BlockMessage> completer = Completer<BlockMessage>();
    addJsonMessage(
      id != null
          ? <String, dynamic>{
              'type': 'get_block',
              'body': <String, dynamic>{
                'block_id': id.toJson(),
              },
            }
          : <String, dynamic>{
              'type': 'get_block_by_height',
              'body': <String, dynamic>{
                'height': height,
              },
            },
      (Map<String, dynamic> response) {
        if (response == null) {
          completer.complete(null);
          return;
        }
        checkEquals('block', response['type'], spec.debugPrint);
        var body = response['body'];
        var block = body['block'];
        completer.complete(BlockMessage(CruzBlockId.fromJson(body['block_id']),
            block != null ? CruzBlock.fromJson(block) : null));
      },
    );
    return completer.future;
  }

  /// GetTransactionMessage is used to request a confirmed transaction.
  /// Type: "get_transaction".
  @override
  Future<TransactionMessage> getTransaction(TransactionId id) {
    Completer<TransactionMessage> completer = Completer<TransactionMessage>();
    addJsonMessage(
      <String, dynamic>{
        'type': 'get_transaction',
        'body': <String, dynamic>{
          'transaction_id': id.toJson(),
        },
      },
      (Map<String, dynamic> response) {
        if (response == null) {
          completer.complete(null);
          return;
        }
        checkEquals('transaction', response['type'], spec.debugPrint);
        var body = response['body'];
        var transaction = body != null ? body['transaction'] : null;
        TransactionMessage ret = TransactionMessage(id,
            transaction != null ? CruzTransaction.fromJson(transaction) : null);
        if (ret.transaction != null) ret.transaction.height = body['height'];
        completer.complete(ret);
      },
    );
    return completer.future;
  }

  /// Handle the cruzbit.1 JSON message frame consisting of [type] and [body].
  void handleMessage(String message) {
    if (spec.debugPrint != null && spec.debugLevel >= debugLevelDebug) {
      debugPrintLong('got cruzabit.1 message ' + message, spec.debugPrint);
    }
    Map<String, dynamic> json = jsonDecode(message);
    Map<String, dynamic> body = json['body'];
    switch (json['type']) {
      case 'balance':
      case 'block':
      case 'block_header':
      case 'filter_result':
      case 'filter_transaction_queue':
      case 'public_key_transactions':
      case 'push_transaction_result':
      case 'tip_header':
      case 'transaction':
      case 'transaction_relay_policy':
        handleProtocol(() {
          dispatchFromOutstanding(json);
          dispatchFromThrottleQueue();
        });
        break;
      case 'filter_block':
      case 'filter_block_undo':
        handleProtocol(() => handleFilterBlock(
            CruzBlockId.fromJson(body['block_id']),
            CruzBlock.fromJson(body),
            json['type'] == 'filter_block_undo'));
        break;
      case 'push_transaction':
        handleProtocol(() => handleNewTransaction(
            CruzTransaction.fromJson(body['transaction'])));
        break;
      default:
        break;
    }
  }

  /// Handles every new [CruzBlock] on the [CruzPeerNetwork].
  /// [CruzBlock.transactions] is empty if no [CruzTransaction] match our [filterAdd()].
  void handleFilterBlock(CruzBlockId id, CruzBlock block, bool undo) {
    if (undo) {
      if (spec.debugPrint != null) {
        spec.debugPrint('got undo!  reorg occurring.');
      }
    }

    /// Call [handleNewTransaction] before [tipChanged] so
    /// [Wallet._expirePendingTransactions] will see transactions in this block.
    if (block.transactions != null) {
      for (CruzTransaction transaction in block.transactions) {
        transaction.height = undo ? -1 : block.header.height;
        handleNewTransaction(transaction);
      }
    }

    if (!undo) {
      int expectedHeight = tip.height + 1;
      tipId = id;
      tip = block.header;
      if (spec.debugPrint != null) {
        spec.debugPrint('new blockHeight=${tip.height} ' +
            (expectedHeight == tip.height ? 'as expected' : 'reorg'));
      }
      if (tipChanged != null) tipChanged();
    }
  }

  /// Handles every new [CruzTransaction] matching our [filterAdd()]
  void handleNewTransaction(CruzTransaction transaction) {
    TransactionCallback cb = transaction.from != null
        ? addressFilter[transaction.from.toJson()]
        : null;
    cb = cb ?? addressFilter[transaction.to.toJson()];
    if (cb != null) cb(transaction);
  }
}

/// The first [CruzBlock] in the chain: https://www.cruzbase.com/#/height/0
const String genesisBlockJson = '''{
  "header": {
    "previous": "0000000000000000000000000000000000000000000000000000000000000000",
    "hash_list_root": "7afb89705316b3de79a3882ec3732b6b8796dd4bf2a80240549ae8fd49a517d8",
    "time": 1561173156,
    "target": "00000000ffff0000000000000000000000000000000000000000000000000000",
    "chain_work": "0000000000000000000000000000000000000000000000000000000100010001",
    "nonce": 1695541686981695,
    "height": 0,
    "transaction_count": 1
  },
  "transactions": [
    {
      "time": 1561173126,
      "nonce": 1654479747,
      "to": "ntkSbbG+b0vo49IGd9nnH39eHIxIEqXmIL8aaJZV+jQ=",
      "amount": 5000000000,
      "memo": "0000000000000000000de6d595bddae743ac032b1458a47ccaef7b0f6f1e3210",
      "series": 1
    }
  ]
}''';
