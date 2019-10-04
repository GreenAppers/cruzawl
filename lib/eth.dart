// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip32/src/utils/ecurve.dart' as ecc;
import "package:convert/convert.dart";
import "package:fixnum/fixnum.dart";
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import "package:pointycastle/src/utils.dart";

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/http.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sha3.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/websocket.dart';

part 'eth.g.dart';

/// Ethereum: A Next-Generation Smart Contract and Decentralized Application Platform
/// Buterin, V. (2013) https://github.com/ethereum/wiki/wiki/White-Paper
class ETH extends Currency {
  const ETH();

  /// Wei is the smallest denomination of ether.
  static const int weiPerEth = 1000000000000000000;

  /// The uncle rate is consistently around 0.06 to 0.08 (or ~6.7%).
  static double averageUncleRate = .075;

  /// Ticker symbol for Ethereum, e.g. ETH.
  @override
  String get ticker => 'ETH';

  /// Official name.
  @override
  String get name => 'Ethereum';

  /// Official link.
  @override
  String get url => 'https://www.ethereum.org/';

  /// The coin type used for HD wallets.
  /// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
  @override
  int get bip44CoinType => 60;

  /// Hardened change in BIP32 path;
  bool get hardenedChange => false;

  /// Ethereum has no period of custory for block rewards.
  @override
  int get coinbaseMaturity => 0;

  /// Format discrete wei value [v] in fractional ETH representation.
  @override
  String format(num v) => v != null ? (v / weiPerEth).toStringAsFixed(4) : '0';

  /// Parse fractional ETH value [v] into discrete wei.
  @override
  num parse(String v) {
    num x = num.tryParse(v);
    return x != null ? (x * weiPerEth).floor() : 0;
  }

  /// Approximate number of ETH issued at [height].
  @override
  int supply(int height) {
    /// https://etherscan.io/stat/supply
    int supply = 72009990, v;
    height -= (v = min(height, 4370000));
    supply += (v * 5 * (1 + averageUncleRate)).toInt();
    height -= (v = min(height, 7080000));
    supply += (v * 3 * (1 + averageUncleRate)).toInt();
    return supply + (height * 2 * (1 + averageUncleRate)).toInt();
  }

  /// Computes the expected block reward for the given [height].
  @override
  int blockCreationReward(int height) {
    if (height < 4370000) {
      return 5;
    } else if (height < 7080000) {
      return 3;
    } else {
      return 2;
    }
  }

  /// 25 GWEI
  @override
  String suggestedFee(Transaction t) => '0.000000025';

  /// Address with the value of zero.
  @override
  PublicAddress get nullAddress => EthereumPublicKey(Uint8List(64));

  /// Create a [InfuraAPINetwork] instance.
  @override
  InfuraAPINetwork createNetwork(
          {VoidCallback peerChanged,
          VoidCallback tipChanged,
          HttpClient httpClient}) =>
      InfuraAPINetwork(peerChanged, tipChanged);

  /// The first [Block] in the chain. e.g. https://www.etherchain.org/block/0
  @override
  EthereumBlock genesisBlock() =>
      EthereumBlock.fromJson(jsonDecode(genesisBlockJson));

  /// SLIP-0010: Universal private key derivation from master private key.
  @override
  EthereumAddress deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]) {
    bip32.BIP32 node = bip32.BIP32.fromSeed(seed);
    bip32.BIP32 child = path == 'm' ? node : node.derivePath(path);
    return EthereumAddress(
        EthereumPublicKey(ecc.pointFromScalar(child.privateKey, false).sublist(1)),
        EthereumPrivateKey(child.privateKey),
        EthereumChainCode(child.chainCode),
        child.index,
        child.depth,
        child.parentFingerprint);
  }

  /// For Watch-only wallets.
  @override
  EthereumAddress fromPublicAddress(PublicAddress addr) {
    EthereumAddressHash hash = EthereumAddressHash.fromJson(addr.toJson());
    return EthereumAddress.fromAddressHash(hash);
  }

  /// For Watch-only wallets.
  @override
  EthereumAddress fromPublicKey(PublicAddress addr) {
    EthereumPublicKey key = EthereumPublicKey.fromJson(addr.toJson());
    return EthereumAddress.fromPublicKey(key);
  }

  /// For non-HD wallets.
  @override
  EthereumAddress fromPrivateKey(PrivateKey key) =>
      EthereumAddress.fromPrivateKey(key);

  /// For loading wallet from storage.
  @override
  EthereumAddress fromAddressJson(Map<String, dynamic> json) =>
      EthereumAddress.fromJson(json);

  /// Parse Ethereum public key hash.
  @override
  PublicAddress fromPublicAddressJson(String text) {
    try {
      return EthereumAddressHash.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse Ethereum public key.
  @override
  EthereumPublicKey fromPublicKeyJson(String text) {
    try {
      return EthereumPublicKey.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse Ethereum private key.
  @override
  EthereumPrivateKey fromPrivateKeyJson(String text) {
    try {
      return EthereumPrivateKey.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse Ethereum block id.
  @override
  EthereumBlockId fromBlockIdJson(String text, [bool pad = false]) {
    try {
      if (pad) {
        return EthereumBlockId.fromString(text);
      } else {
        return EthereumBlockId.fromJson(text);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parse Ethereum transaction id.
  @override
  EthereumTransactionId fromTransactionIdJson(String text, [bool pad = false]) {
    try {
      if (pad) {
        return EthereumTransactionId.fromString(text);
      } else {
        return EthereumTransactionId.fromJson(text);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parse Ethereum transaction.
  @override
  EthereumTransaction fromTransactionJson(Map<String, dynamic> json) =>
      EthereumTransaction.fromJson(json);

  /// Creates signed Ethereum transaction.
  @override
  EthereumTransaction signedTransaction(Address fromInput,
      PublicAddress toInput, num amount, num fee, String memo, int height,
      {int matures, int expires}) {
    if (!(fromInput is EthereumAddress)) throw FormatException();
    if (!(toInput is EthereumPublicKey)) throw FormatException();
    //EthereumAddress from = fromInput;
    //EthereumPublicKey to = toInput;
    return null;
  }

  static String hexEncode(Uint8List x, [bool prefix = true]) =>
      (prefix ? '0x' : '') + hex.encode(x);

  static Uint8List hexDecode(String x) =>
      hex.decode(x.startsWith('0x') ? x.substring(2) : x);

  static String hexEncodeInt64(Int64 x, [bool prefix = true]) =>
      (prefix ? '0x' : '') + x.toHexString();

  static Int64 hexDecodeInt64(String x) =>
      Int64.parseHex(x.startsWith('0x') ? x.substring(2) : x);

  static String hexEncodeInt(int x, [bool prefix = true]) =>
      (prefix ? '0x' : '') + x.toRadixString(16);

  static int hexDecodeInt(String x) => x == null ? null : int.tryParse(x);
}

/// Right 20 bytes of Keccack-256.
@immutable
class EthereumAddressHash extends PublicAddress {
  final Uint8List data;
  static const int size = 20;

  /// Fully specified constructor used by JSON deserializer.
  EthereumAddressHash(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// For a given private key, pr, the Ethereum address A(pr) (a 160-bit value) to which it corresponds
  /// is defined as the right most 160-bits of the Keccak hash of the corresponding ECDSA public key.
  EthereumAddressHash.compute(EthereumPublicKey publicKey)
      : data = keccak(publicKey.data).sublist(12);

  /// Unmarshals a hex-encoded string to [EthereumAddressHash].
  factory EthereumAddressHash.fromJson(String x) {
    try {
      Uint8List ret = ETH.hexDecode(x);
      return EthereumAddressHash(ret);
    } catch (_) {
      return null;
    }
  }

  /// Marshals [EthereumAddressHash] as a hex-encoded string.
  @override
  String toJson() => ETH.hexEncode(data);

  /// Keccak-256 hash.
  static Uint8List keccak(Uint8List input) =>
      SHA3Digest(256, true).process(input);
}

/// ECDSA public key, no-prefix byte: 64 bytes.
@immutable
class EthereumPublicKey extends PublicAddress {
  final Uint8List data;
  static const int size = 64;

  /// Fully specified constructor used by JSON deserializer.
  EthereumPublicKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a hex-encoded string to [EthereumPublicKey].
  EthereumPublicKey.fromJson(String x) : this(ETH.hexDecode(x));

  /// Marshals [EthereumPublicKey] as a hex-encoded string.
  @override
  String toJson() => ETH.hexEncode(data);
}

/// ECDSA private key, 32 bytes
@immutable
class EthereumPrivateKey extends PrivateKey {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  EthereumPrivateKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a hex-encoded string to [EthereumPrivateKey].
  EthereumPrivateKey.fromJson(String text) : this(ETH.hexDecode(text));

  /// Marshals [EthereumPrivateKey] as a hex-encoded string.
  @override
  String toJson() => ETH.hexEncode(data);

  /// Used to verify the key pair.
  EthereumPublicKey derivePublicKey() =>
      EthereumPublicKey(ecc.pointFromScalar(data, false).sublist(1));
}

/// ECDSA signature, 64 bytes.
@immutable
class EthereumSignature extends Signature {
  final Uint8List data;
  static const int size = 64;

  /// Fully specified constructor used by JSON deserializer.
  EthereumSignature(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals hex string to [EthereumSignature].
  EthereumSignature.fromJson(String x) : this(ETH.hexDecode(x));

  /// Marshals [EthereumSignature] as a hex string.
  @override
  String toJson() => ETH.hexEncode(data);
}

/// SLIP-0010 chain code.
@immutable
class EthereumChainCode extends ChainCode {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  EthereumChainCode(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a hex-encoded string to [EthereumChainCode].
  EthereumChainCode.fromJson(String x) : this(ETH.hexDecode(x));

  /// Marshals [EthereumChainCode] as a hex-encoded string.
  @override
  String toJson() => ETH.hexEncode(data);
}

/// Hash of the bitcoin transaction.
@immutable
class EthereumTransactionId extends TransactionId {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  EthereumTransactionId(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Computes the hash of [transaction] - not implemented.
  EthereumTransactionId.compute(EthereumTransaction transaction) : data = null;

  /// Unmarshals a hex string to [EthereumTransactionId].
  EthereumTransactionId.fromJson(String x) : this(ETH.hexDecode(x));

  /// Unmarshals a hex string (with leading zeros optionally truncated) to [EthereumTransactionId].
  EthereumTransactionId.fromString(String x)
      : this(zeroPadUint8List(
            ETH.hexDecode(zeroPadOddLengthHexString(x)), size));

  /// Marshals [EthereumTransactionId] as a hex string.
  @override
  String toJson() => ETH.hexEncode(data);
}

/// Shim [TransactionInput] for ETH which has only a single input and output.
class EthereumTransactionInput extends TransactionInput {
  @override
  EthereumAddressHash address;

  @override
  int value;

  EthereumTransactionInput(this.address, this.value);

  // The hex-encoded sender of this transaction.
  @override
  String get fromText => address.toJson();

  /// Ethereum uses [EthereumBlockHeader.miner] instead of coinbase transactions.
  @override
  bool get isCoinbase => false;
}

/// Shim [TransactionOutput] for ETH which has only a single input and output.
class EthereumTransactionOutput extends TransactionOutput {
  @override
  EthereumAddressHash address;

  @override
  int value;

  EthereumTransactionOutput(this.address, this.value);
}

/// Ethereum, taken as a whole, can be viewed as a transaction-based state machine.
/// Transactions thus represent a valid arc between two states.
@JsonSerializable(includeIfNull: false)
class EthereumTransaction extends Transaction {
  /// Identifier for this transaction.
  @override
  EthereumTransactionId hash;

  /// Integer of the transactions index position in the block. null when its pending.
  @JsonKey(name: 'transactionIndex', fromJson: ETH.hexDecodeInt)
  int index;

  /// Used by [Wallet].
  @override
  @JsonKey(name: 'blockNumber', fromJson: ETH.hexDecodeInt)
  int height = 0;

  /// The number of transactions made by the sender prior to this one.
  @override
  @JsonKey(fromJson: ETH.hexDecodeInt)
  int nonce;

  /// Address of the sender.
  EthereumAddressHash from;

  /// Address of the receiver. null when its a contract creation transaction.
  EthereumAddressHash to;

  /// Value transferred in Wei.
  @override
  @JsonKey(name: 'value', fromJson: ETH.hexDecodeInt)
  int amount;

  /// Gas provided by the sender
  @JsonKey(fromJson: ETH.hexDecodeInt)
  int gas;

  /// Gas price provided by the sender in Wei.
  @JsonKey(fromJson: ETH.hexDecodeInt)
  int gasPrice;

  /// The data send along with the transaction.
  @JsonKey(fromJson: ETH.hexDecode)
  Uint8List input;

  @override
  DateTime get dateTime => null;

  @override
  bool get isCoinbase => from == null;

  @override
  List<EthereumTransactionInput> get inputs =>
      [EthereumTransactionInput(from, amount + (fee ?? 0))];

  @override
  List<EthereumTransactionOutput> get outputs =>
      [EthereumTransactionOutput(to, amount)];

  /// The handling fee paid to the [PeerNetwork] for this transaction.
  @override
  int get fee => 0;

  /// Max 100 characters.
  @override
  String get memo => null;

  /// Block height. If set transaction can't be mined before.
  @override
  int get matures => null;

  /// Block height. If set transaction can't be mined after.
  @override
  int get expires => null;

  /// Creates an arbitrary unsigned [EthereumTransaction].
  EthereumTransaction();

  /// Unmarshals a JSON-encoded string to [EthereumTransaction].
  factory EthereumTransaction.fromJson(Map<String, dynamic> json) =>
      _$EthereumTransactionFromJson(json);

  /// Marshals [EthereumTransaction] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$EthereumTransactionToJson(this);

  /// Computes an ID for this transaction.
  @override
  EthereumTransactionId id() => hash;

  /// Signs this transaction.
  void sign(EthereumPrivateKey key) {}

  /// Verify only that the transaction is properly signed.
  @override
  bool verify() => false;
}

/// Ethereum implementation of the [Wallet] entry [Address] abstraction.
@JsonSerializable(includeIfNull: false)
class EthereumAddress extends Address {
  // BIP32 depth.
  int chainDepth;

  /// BIP32: the fingerprint of the parent's key.
  int parentFingerprint;

  /// The public address of this [EthereumAddress].
  @override
  EthereumAddressHash publicAddress;

  /// The public key of this [EthereumAddress].
  @override
  EthereumPublicKey publicKey;

  /// The private key for this address, if not watch-only.
  @override
  EthereumPrivateKey privateKey;

  /// The chain code for this address, if HD derived.
  @override
  EthereumChainCode chainCode;

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
  EthereumAddress(this.publicKey, this.privateKey, this.chainCode,
      int chainIndex, this.chainDepth, this.parentFingerprint) {
    this.chainIndex = chainIndex;
    if (publicKey == null) {
      throw FormatException();
    }
    publicAddress = EthereumAddressHash.compute(publicKey);
  }

  /// Element of watch-only [Wallet].
  EthereumAddress.fromAddressHash(this.publicAddress);

  /// Element of watch-only [Wallet].
  EthereumAddress.fromPublicKey(this.publicKey) {
    publicAddress = EthereumAddressHash.compute(publicKey);
  }

  /// Element of non-HD [Wallet].
  EthereumAddress.fromPrivateKey(this.privateKey) {
    publicKey = privateKey.derivePublicKey();
    publicAddress = EthereumAddressHash.compute(publicKey);
  }

  /// Element of HD [Wallet].
  factory EthereumAddress.fromSeed(Uint8List seed) {
    assert(ecc.isPrivate(seed));
    return EthereumAddress.fromPrivateKey(EthereumPrivateKey(seed));
  }

  /// Generate a random [EthereumAddress]. Not used by [Wallet].
  factory EthereumAddress.generateRandom() =>
      EthereumAddress.fromSeed(randomSeed());

  /// Unmarshals a JSON-encoded string to [EthereumAddress].
  factory EthereumAddress.fromJson(Map<String, dynamic> json) =>
      _$EthereumAddressFromJson(json);

  /// Marshals [EthereumAddress] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$EthereumAddressToJson(this);

  /// Verifies [privateKey] produces [publicKey].
  bool verify() =>
      privateKey != null &&
      equalUint8List(publicKey.data, privateKey.derivePublicKey().data);

  /// Generates a random seed for [fromSeed].
  static Uint8List randomSeed() {
    Uint8List seed;
    do {
      seed = randBytes(32);
    } while (!ecc.isPrivate(seed));
    return seed;
  }
}

/// Unique identifier for [Block].
@immutable
class EthereumBlockId extends BlockId {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  EthereumBlockId(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Computes the hash of [blockHeaderJson].
  EthereumBlockId.compute(String blockHeaderJson) : data = null;

  /// Decodes [BigInt] to [EthereumBlockId].
  EthereumBlockId.fromBigInt(BigInt x)
      : this(zeroPadUint8List(encodeBigInt(x), size));

  /// Unmarshals hex string to [EthereumBlockId].
  EthereumBlockId.fromJson(String x) : this(ETH.hexDecode(x));

  /// Unmarshals hex string (with leading zeros optionally truncated) to [EthereumBlockId].
  EthereumBlockId.fromString(String x)
      : this(zeroPadUint8List(
            ETH.hexDecode(zeroPadOddLengthHexString(x)), size));

  /// Marshals [EthereumBlockId] as a hex string.
  @override
  String toJson() => ETH.hexEncode(data);

  /// Decodes a [BigInt] representation.
  @override
  BigInt toBigInt() => decodeBigInt(data);
}

/// List of [EthereumBlockId]
@JsonSerializable()
class EthereumBlockIds {
  List<EthereumBlockId> block_ids;
  EthereumBlockIds();

  /// Unmarshals a JSON-encoded string to [EthereumBlockIds].
  factory EthereumBlockIds.fromJson(Map<String, dynamic> json) =>
      _$EthereumBlockIdsFromJson(json);

  /// Marshals [EthereumBlockIds] as a JSON-encoded string.
  Map<String, dynamic> toJson() => _$EthereumBlockIdsToJson(this);
}

/// Data used to determine block validity and place in the block chain.
@JsonSerializable(includeIfNull: false)
class EthereumBlockHeader extends BlockHeader {
  // Hash of the block.
  EthereumBlockId hash;

  /// Hash of the parent block.
  @override
  @JsonKey(name: 'parentHash')
  EthereumBlockId previous;

  /// The root of the transaction trie of the block.
  @JsonKey(name: 'transactionsRoot')
  EthereumTransactionId hashRoot;

  /// The unix timestamp for when the block was collated.
  @JsonKey(name: 'timestamp', fromJson: ETH.hexDecodeInt)
  int time;

  @override
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true).toLocal();

  /// Integer of the difficulty for this block.
  BigInt difficulty;

  /// Integer of the total difficulty of the chain until this block.
  BigInt totalDifficulty;

  /// Threshold new [EthereumBlock] must hash under for Proof of Work.
  @override
  BlockId get target {
    BigInt twoTo256 = decodeBigInt(Uint8List(33)..[0] = 1);
    return EthereumBlockId.fromBigInt(twoTo256 ~/ difficulty);
  }

  /// Total cumulative chain work.
  @override
  EthereumBlockId get chainWork => EthereumBlockId.fromBigInt(totalDifficulty);

  /// Parameter varied by miners for Proof of Work.
  @override
  @JsonKey(name: 'nonce')
  BigInt nonceValue;

  /// Height is eventually unique.
  @override
  @JsonKey(name: 'number', fromJson: ETH.hexDecodeInt)
  int height;

  /// The number of transactions in this block.
  @override
  int get transactionCount => null;

  /// The address of the beneficiary to whom the mining rewards were given.
  EthereumAddressHash miner;

  /// Integer the size of this block in bytes.
  @JsonKey(fromJson: ETH.hexDecodeInt)
  int size;

  /// Default constructor used by JSON deserializer.
  EthereumBlockHeader();

  /// Unmarshals a JSON-encoded string to [EthereumBlockHeader].
  factory EthereumBlockHeader.fromJson(Map<String, dynamic> json) =>
      _$EthereumBlockHeaderFromJson(json);

  /// Marshals [EthereumBlockHeader] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$EthereumBlockHeaderToJson(this);

  /// Expected number of random hashes before mining this block.
  @override
  BigInt blockWork() => difficulty;

  /// Computes an ID for this block.
  @override
  EthereumBlockId id() => hash;
}

/// Represents a block in the block chain. It has a header and a list of transactions.
class EthereumBlock extends Block {
  /// Header has [transactions] checksums and Proof of Work.
  @override
  EthereumBlockHeader header;

  /// The list of [EthereumTransaction] in this block of the ledger.
  @override
  List<EthereumTransaction> transactions;

  /// Unmarshals a JSON-encoded string to [EthereumBlock].
  EthereumBlock.fromJson(Map<String, dynamic> json) {
    header = EthereumBlockHeader.fromJson(json);
    if (json['transactions'] != null) {
      transactions = json['transactions']
          .map((t) => EthereumTransaction.fromJson(t))
          .toList()
          .cast<EthereumTransaction>();
    }
  }

  /// Marshals [EthereumBlock] as a JSON-encoded string.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = header.toJson();
    ret['transactions'] = transactions.map((t) => t.toJson()).toList();
    return ret;
  }

  /// Computes an ID for this block.
  @override
  EthereumBlockId id() => header.id();

  /// Compute a Merkle tree root of all transaction hashes.
  @override
  EthereumTransactionId computeHashRoot() => null;
}

/// https://infura.io/docs/ethereum/wss/introduction.md
class InfuraAPINetwork extends PeerNetwork {
  InfuraAPINetwork(VoidCallback peerChanged, VoidCallback tipChanged)
      : super(peerChanged, tipChanged);

  @override
  ETH get currency => eth;

  /// Creates [Peer] ready to [Peer.connect()].
  @override
  Peer createPeerWithSpec(PeerPreference spec) =>
      InfuraAPI(spec, parseUri(spec.url));

  /// Valid INFURA URI: 'mainnet.infura.io', 'wss://mainnet.infura.io/ws/v3/YOUR-PROJECT-ID'.
  String parseUri(String uriText) {
    if (!Uri.parse(uriText).hasScheme) uriText = 'wss://' + uriText;
    Uri uri = Uri.parse(uriText);
    Uri url = uri.replace(
        path: uri.path.isEmpty
            ? '/ws/v3/3b9c62d39b5f4dc5b0d78f2c717fb2f1'
            : uri.path);
    return url.toString();
  }
}

/// INFURA implementation of the [PeerNetwork] entry [Peer] abstraction.
/// Reference: https://infura.io/docs/ethereum/wss/introduction.md
class InfuraAPI extends PersistentWebSocketClient with JsonResponseMapMixin {
  /// The [EthereumAddress] we're monitoring [InfuraAPINetwork] for.
  Map<String, TransactionCallback> addressFilter =
      Map<String, TransactionCallback>();

  /// Height of tip [EthereumBlock] according to this peer.
  @override
  int tipHeight;

  /// ID of tip [EthereumBlock] according to this peer.
  @override
  EthereumBlockId tipId;

  /// The minimum [EthereumTransaction.amount] for the [InfuraAPINetwork].
  @override
  num minAmount;

  /// The minimum [EthereumTransaction.fee] for the [InfuraAPINetwork].
  @override
  num minFee;

  /// INFURA heads subscription id.
  String headsSubscription;

  /// Forward [Peer] constructor.
  InfuraAPI(PeerPreference spec, String webSocketAddress)
      : super(spec, webSocketAddress) {
    queryNumberField = 'id';
  }

  /// Network lost. Clear [tip] and [tipId].
  @override
  void handleDisconnected() {
    addressFilter = Map<String, TransactionCallback>();
    tipId = null;
    tipHeight = null;
  }

  /// Network connected. Request [tip] and subscribe to new blocks.
  @override
  void handleConnected() {
    /// Creates a filter in the node, to notify when a new block arrives.
    addJsonMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'eth_subscribe',
      'params': <String>['newHeads'],
    }, (Map<String, dynamic> response) {
      if (response == null) return;
      headsSubscription = response['result'];
    });

    /// Returns the current "latest" block number.
    addJsonMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'eth_blockNumber',
      'params': [],
    }, (Map<String, dynamic> response) {
      if (response == null) return;
      tipHeight = ETH.hexDecodeInt(response['result']);
      if (spec.debugPrint != null) {
        spec.debugPrint('ETH initial blockHeight=${tipHeight}');
      }
      setState(PeerState.ready);
      if (tipChanged != null) tipChanged();
    });
  }

  /// Returns the balance of the account of given address.
  @override
  Future<num> getBalance(PublicAddress address) {
    Completer<num> completer = Completer<num>();
    String addressText = address.toJson();
    addJsonMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'eth_getBalance',
      'params': [addressText, 'latest'],
    }, (Map<String, dynamic> response) {
      completer
          .complete(response == null ? null : ETH.hexDecodeInt(response['result']));
    });
    return completer.future;
  }

  @override
  Future<TransactionIteratorResults> getTransactions(
      PublicAddress address, TransactionIterator iterator,
      {int limit = 50}) {
    return getAddressLogs(address,
        offset: iterator != null ? iterator.index : 0, limit: limit);
  }

  Future<TransactionIteratorResults> getAddressLogs(
      PublicAddress address,
      {int offset = 0,
      int limit = 50}) {
    Completer<TransactionIteratorResults> completer =
        Completer<TransactionIteratorResults>();
    /// Returns an array of all logs matching a given filter object.
    addJsonMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'eth_getLogs',
      'params': [{'address': address.toJson()}],
    }, (Map<String, dynamic> response) {
      spec.debugPrint("got ${jsonEncode(response)}");
      completer.complete(null);
    });
    return completer.future;
  }

  @override
  Future<TransactionId> putTransaction(Transaction transaction) {
    Completer<TransactionId> completer = Completer<TransactionId>();
    /// TODO: eth_sendRawTransaction
    return completer.future;
  }

  /// Returns logs that are included in new imported blocks and match the given filter criteria.
  /// In case of a chain reorganization previous sent logs that are on the old chain will be resend
  /// with the removed property set to true. Logs from transactions that ended up in the new chain are emitted.
  /// Therefore a subscription can emit logs for the same transaction multiple times.
  @override
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb) {
    Completer<bool> completer = Completer<bool>();
    addressFilter[address.toJson()] = transactionCb;
    addJsonMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'eth_subscribe',
      'params': ['logs', {'address': address.toJson()} ],
    }, (Map<String, dynamic> response) {
      completer.complete(response != null);
    });
    return completer.future;
  }

  @override
  Future<bool> filterTransactionQueue() {
    /// No way to use eth_subscribe newPendingTransactions?
    return Future.value(true);
  }

  /// Returns information about a block.
  @override
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height}) {
    Completer<BlockHeaderMessage> completer = Completer<BlockHeaderMessage>();
    if (id != null) {
      /// Returns information about a block by hash.
      addJsonMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'eth_getBlockByHash',
        'params': [id.toJson(), false],
      }, (Map<String, dynamic> response) {
        Map<String, dynamic> block =
            response == null ? null : response['result'];
        if (block == null) {
          completer.complete(null);
          return;
        }
        completer.complete(BlockHeaderMessage(
            EthereumBlockId.fromJson(block['hash']),
            EthereumBlockHeader.fromJson(block)));
      });
    } else {
      /// Returns information about a block by number.
      addJsonMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'eth_getBlockByNumber',
        'params': [ETH.hexEncodeInt(height), false],
      }, (Map<String, dynamic> response) {
        Map<String, dynamic> block =
            response == null ? null : response['result'];
        if (block == null) {
          completer.complete(null);
          return;
        }
        completer.complete(BlockHeaderMessage(
            EthereumBlockId.fromJson(block['hash']),
            EthereumBlockHeader.fromJson(block)));
      });
    }
    return null;
  }

  /// Returns information about a block.
  @override
  Future<BlockMessage> getBlock({BlockId id, int height}) {
    Completer<BlockMessage> completer = Completer<BlockMessage>();
    if (id != null) {
      /// Returns information about a block by hash.
      addJsonMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'eth_getBlockByHash',
        'params': [id.toJson(), true],
      }, (Map<String, dynamic> response) {
        Map<String, dynamic> block =
            response == null ? null : response['result'];
        if (block == null) {
          completer.complete(null);
          return;
        }
        completer.complete(BlockMessage(EthereumBlockId.fromJson(block['hash']),
            EthereumBlock.fromJson(block)));
      });
    } else {
      /// Returns information about a block by number.
      addJsonMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'eth_getBlockByNumber',
        'params': [ETH.hexEncodeInt(height), true],
      }, (Map<String, dynamic> response) {
        Map<String, dynamic> block =
            response == null ? null : response['result'];
        if (block == null) {
          completer.complete(null);
          return;
        }
        completer.complete(BlockMessage(EthereumBlockId.fromJson(block['hash']),
            EthereumBlock.fromJson(block)));
      });
    }
    return completer.future;
  }

  /// Returns information about a transaction for a given hash.
  @override
  Future<TransactionMessage> getTransaction(TransactionId id) {
    Completer<TransactionMessage> completer = Completer<TransactionMessage>();
    addJsonMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'eth_getTransactionByHash',
      'params': [id.toJson(), true],
    }, (Map<String, dynamic> response) {
      Map<String, dynamic> transaction =
          response == null ? null : response['result'];
      if (transaction == null) {
        completer.complete(null);
        return;
      }
      completer.complete(TransactionMessage(
          EthereumTransactionId.fromJson(transaction['hash']),
          EthereumTransaction.fromJson(transaction)));
    });
    return completer.future;
  }

  /// Handle the INFURA WebSocket API message frame.
  void handleMessage(String message) {
    if (spec.debugPrint != null && spec.debugLevel >= debugLevelDebug) {
      debugPrintLong('got infura API message ' + message, spec.debugPrint);
    }
    Map<String, dynamic> json = jsonDecode(message);
    Map<String, dynamic> params = json == null ? null : json['params'];
    Map<String, dynamic> result = params == null ? null : params['result'];
    if (json['method'] == 'eth_subscription') {
      if (params['subscription'] == headsSubscription) {
        handleProtocol(() => handleFilterBlock(
            result['hash'] == null
                ? null
                : EthereumBlockId.fromJson(result['hash']),
            EthereumBlock.fromJson(result),
            false));
      } else {
        assert(result['blockNumber'] != null);
        assert(result['transactionIndex'] != null);

        /// Fetch the transaction associated with this log.
        addJsonMessage(<String, dynamic>{
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionByBlockNumberAndIndex',
          'params': [ result['blockNumber'] , result['transactionIndex'] ],
        }, (Map<String, dynamic> x) =>
        handleProtocol(
            () => handleNewTransaction(EthereumTransaction.fromJson(x)))
        );
      }
    } else {
      handleProtocol(() {
        dispatchFromOutstanding(json);
        dispatchFromThrottleQueue();
      });
    }
  }

  /// Handles every new [EthereumBlock] on the [InfuraAPINetwork].
  /// [EthereumBlock.transactions] is empty if no [EthereumTransaction] match our [filterAdd()].
  void handleFilterBlock(EthereumBlockId id, EthereumBlock block, bool undo) {
    if (tipId == null) {
      tipId = id;
      tipHeight = block.header.height;
      if (spec.debugPrint != null) {
        spec.debugPrint('initial blockHeight=${tipHeight}');
      }
      setState(PeerState.ready);
      if (tipChanged != null) tipChanged();
      return;
    }

    if (undo) {
      if (spec.debugPrint != null) {
        spec.debugPrint('got undo!  reorg occurring.');
      }
    }

    /// Call [handleNewTransaction] before [tipChanged] so
    /// [Wallet._expirePendingTransactions] will see transactions in this block.
    if (block.transactions != null) {
      for (EthereumTransaction transaction in block.transactions) {
        transaction.height = undo ? -1 : block.header.height;
        handleNewTransaction(transaction);
      }
    }

    if (!undo) {
      int expectedHeight = tipHeight + 1;
      tipId = id;
      tipHeight = block.header.height;
      if (spec.debugPrint != null) {
        spec.debugPrint('new blockHeight=${tipHeight} ' +
            (expectedHeight == tipHeight ? 'as expected' : 'reorg'));
      }
      if (tipChanged != null) tipChanged();
    }
  }

  /// Handles every new [EthereumTransaction] matching our [filterAdd()]
  void handleNewTransaction(EthereumTransaction transaction) {
    TransactionCallback cb = transaction.from != null
        ? addressFilter[transaction.from.toJson()]
        : null;
    cb = cb ?? addressFilter[transaction.to.toJson()];
    if (cb != null) cb(transaction);
  }
}

/// The first [EthereumBlock] in the chain: https://www.etherchain.org/block/0
const String genesisBlockJson = '''{
  "difficulty": "0x400000000",
  "extraData": "0x11bbe8db4e347b4e8c937c1c8370e4b5ed33adb3db69cbdb7a38e1e50b1b82fa",
  "gasLimit": "0x1388",
  "gasUsed": "0x0",
  "hash": "0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3",
  "logsBloom": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "miner": "0x0000000000000000000000000000000000000000",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "nonce": "0x0000000000000042",
  "number": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "receiptsRoot": "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
  "sha3Uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
  "size": "0x21c",
  "stateRoot": "0xd7f8974fb5ac78d9ac099b9ad5018bedc2ce0a72dad1827a1709da30580f0544",
  "timestamp": "0x0",
  "totalDifficulty": "0x400000000",
  "transactions": [],
  "transactionsRoot": "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
  "uncles": []
}''';
