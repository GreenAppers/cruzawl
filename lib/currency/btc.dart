// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip32/src/utils/ecurve.dart' as ecc;
import 'package:bip32/src/utils/wif.dart' as wif;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:convert/convert.dart';
import 'package:dartssh/serializable.dart' hide equalUint8List;
import 'package:json_annotation/json_annotation.dart';
import 'package:merkletree/merkletree.dart';
import 'package:meta/meta.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/src/utils.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/network/http.dart';
import 'package:cruzawl/network/socket.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

part 'btc.g.dart';

/// Bitcoin: A Peer-to-Peer Electronic Cash System
/// Nakamoto, S. (2008) https://bitcoin.org/bitcoin.pdf
/// https://github.com/trottier/original-bitcoin
class BTC extends Currency {
  const BTC();

  /// The satoshi is currently the smallest unit of the bitcoin currency.
  /// It is one hundred millionth of a single bitcoin (0.00000001 BTC).
  /// Reference: https://en.bitcoin.it/wiki/Satoshi_(unit)
  static const int satoshisPerBitcoin = 100000000;

  /// Initial BTC reward for mining a block.
  static const int initialCoinbaseReward = 50;

  /// 4 years in blocks.
  static const int blocksUntilRewardHalving = 210000;

  /// Ticker symbol for Bitcoin, e.g. BTC.
  @override
  String get ticker => 'BTC';

  /// Official name.
  @override
  String get name => 'Bitcoin';

  /// Original source code.
  @override
  String get url => 'https://github.com/trottier/original-bitcoin';

  @override
  String get supplementalApiUrl => 'https://blockchain.info';

  /// The coin type used for HD wallets.
  /// Reference: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
  @override
  int get bip44CoinType => 0;

  /// Hardened change in BIP32 path;
  bool get hardenedChange => false;

  /// Coinbase transactions mature after 100 blocks.
  /// Reference: https://github.com/trottier/original-bitcoin/blob/master/src/main.h#L20
  @override
  int get coinbaseMaturity => 100;

  /// Format discrete satoshi value [v] in fractional BTC representation.
  @override
  String format(num v) =>
      v != null ? (v / satoshisPerBitcoin).toStringAsFixed(4) : '0';

  /// Parse fractional BTC value [v] into discrete satoshis.
  @override
  num parse(String v) {
    num x = num.tryParse(v);
    return x != null ? (x * satoshisPerBitcoin).floor() : 0;
  }

  /// Returns number of BTC issued at [height].
  @override
  int supply(int blocks) {
    int supply = 0, reward = initialCoinbaseReward * satoshisPerBitcoin;
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
    return supply ~/ satoshisPerBitcoin;
  }

  /// Computes the expected block reward for the given [height].
  @override
  int blockCreationReward(int height) {
    int halvings = height ~/ blocksUntilRewardHalving;
    return halvings >= 64
        ? 0
        : (initialCoinbaseReward * satoshisPerBitcoin) >> halvings;
  }

  /// 0.000011
  /// Reference: https://bitcoinexchangerate.org/fees
  @override
  String suggestedFee(Transaction t) => '0.000011';

  /// Address with the value of zero.
  @override
  PublicAddress get nullAddress => BitcoinPublicKey(Uint8List(33));

  /// Supports Bitcoin Protocol, Bitcoin RPC, and blockchain.info API.
  @override
  List<String> get supportedPeerTypes =>
      ['Bitcoin', 'BitcoinRPC', 'BlockChainAPI'];

  /// Create a [BitcoinNetwork] instance.
  @override
  BitcoinNetwork createNetwork(
          {VoidCallback peerChanged,
          VoidCallback tipChanged,
          HttpClient httpClient,
          String userAgent}) =>
      BitcoinNetwork(httpClient, peerChanged, tipChanged, userAgent);

  /// The first [Block] in the chain. e.g. https://www.blockchain.com/btc/block-height/0
  @override
  BitcoinBlock genesisBlock() =>
      BitcoinBlock.fromJson(jsonDecode(genesisBlockJson));

  /// SLIP-0010: Universal private key derivation from master private key.
  @override
  BitcoinAddress deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]) {
    bip32.BIP32 node = bip32.BIP32.fromSeed(seed);
    bip32.BIP32 child = path == 'm' ? node : node.derivePath(path);
    return BitcoinAddress(
        BitcoinPublicKey(child.publicKey),
        BitcoinPrivateKey(child.privateKey),
        BitcoinChainCode(child.chainCode),
        child.index,
        child.depth,
        child.parentFingerprint);
  }

  /// For Watch-only wallets.
  @override
  BitcoinAddress fromPublicAddress(PublicAddress addr) {
    BitcoinAddressHash hash = BitcoinAddressHash.fromJson(addr.toJson());
    return BitcoinAddress.fromAddressHash(hash);
  }

  /// For Watch-only wallets.
  @override
  BitcoinAddress fromPublicKey(PublicAddress addr) {
    BitcoinPublicKey key = BitcoinPublicKey.fromJson(addr.toJson());
    return BitcoinAddress.fromPublicKey(key);
  }

  /// For non-HD wallets.
  @override
  BitcoinAddress fromPrivateKey(PrivateKey key) =>
      BitcoinAddress.fromPrivateKey(key);

  /// For loading wallet from storage.
  @override
  BitcoinAddress fromAddressJson(Map<String, dynamic> json) =>
      BitcoinAddress.fromJson(json);

  /// Parse Bitcoin public key hash.
  @override
  PublicAddress fromPublicAddressJson(String text) {
    try {
      return BitcoinAddressHash.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse Bitcoin public key.
  @override
  BitcoinPublicKey fromPublicKeyJson(String text) {
    try {
      return BitcoinPublicKey.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse Bitcoin private key.
  @override
  BitcoinPrivateKey fromPrivateKeyJson(String text) {
    try {
      return BitcoinPrivateKey.fromJson(text);
    } catch (_) {
      return null;
    }
  }

  /// Parse Bitcoin block id.
  @override
  BitcoinBlockId fromBlockIdJson(String text, [bool pad = false]) {
    try {
      if (pad) {
        return BitcoinBlockId.fromString(text);
      } else {
        return BitcoinBlockId.fromJson(text);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parse Bitcoin transaction id.
  @override
  BitcoinTransactionId fromTransactionIdJson(String text, [bool pad = false]) {
    try {
      if (pad) {
        return BitcoinTransactionId.fromString(text);
      } else {
        return BitcoinTransactionId.fromJson(text);
      }
    } catch (_) {
      return null;
    }
  }

  /// Parse Bitcoin transaction.
  @override
  BitcoinTransaction fromTransactionJson(Map<String, dynamic> json) =>
      BitcoinTransaction.fromJson(json);

  /// Creates signed Bitcoin transaction.
  @override
  BitcoinTransaction signedTransaction(Address fromInput, PublicAddress toInput,
      num amount, num fee, String memo, int height,
      {int matures, int expires}) {
    if (!(fromInput is BitcoinAddress)) throw FormatException();
    if (!(toInput is BitcoinPublicKey)) throw FormatException();
    //BitcoinAddress from = fromInput;
    //BitcoinPublicKey to = toInput;
    return null;
  }

  // BIP32 serialization constants.
  static bip32.NetworkType network = bip32.NetworkType(
      wif: 0x80,
      bip32: bip32.Bip32Type(public: 0x0488b21e, private: 0x0488ade4));

  /// Double SHA256 hash.
  static Uint8List doubleSha256(Uint8List input) =>
      SHA256Digest().process(SHA256Digest().process(input));

  static String deserializeVarString(SerializableInput input) =>
      String.fromCharCodes(input.getBytes(deserializeVarInt(input)));

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Variable_length_string
  static void serializeVarString(SerializableOutput output, String x) =>
      serializeVarStringBytes(output, Uint8List.fromList(x.codeUnits));

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Variable_length_string
  static void serializeVarStringBytes(SerializableOutput output, Uint8List x) {
    serializeVarInt(output, x.length);
    output.addBytes(x);
  }

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Variable_length_string
  static int varStringLength(int x) => varIntLength(x) + x;

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Variable_length_integer
  static int deserializeVarInt(SerializableInput input) {
    int x = input.getUint8();
    switch (x) {
      case 0xff:
        return input.getUint64();
      case 0xfe:
        return input.getUint32();
      case 0xfd:
        return input.getUint16();
      default:
        return x;
    }
  }

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Variable_length_integer
  static void serializeVarInt(SerializableOutput output, int x) {
    if (x <= 0xfd) {
      output.addUint8(x);
    } else if (x <= 0xffff) {
      output.addUint8(0xfd);
      output.addUint16(x);
    } else if (x <= 0xffffffff) {
      output.addUint8(0xfe);
      output.addUint32(x);
    } else {
      output.addUint8(0xff);
      output.addUint64(x);
    }
  }

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Variable_length_integer
  static int varIntLength(int x) {
    if (x <= 0xFD) {
      return 1;
    } else if (x <= 0xffff) {
      return 3;
    } else if (x <= 0xffffffff) {
      return 5;
    } else {
      return 9;
    }
  }
}

/// Checksummed Hash160.
@immutable
class BitcoinAddressHash extends PublicAddress {
  final Uint8List data;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinAddressHash(this.data);

  /// https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
  BitcoinAddressHash.fromExtendedIdentifier(Uint8List extended)
      : data = Uint8List.fromList(
            extended + BTC.doubleSha256(extended).sublist(0, 4));

  /// https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
  BitcoinAddressHash.compute(BitcoinAddressIdentifier input, [int version = 0])
      : this.fromExtendedIdentifier(Uint8List.fromList([version] + input.data));

  /// Unmarshals a base58-encoded string to [BitcoinAddressHash].
  factory BitcoinAddressHash.fromJson(String x) {
    try {
      Uint8List ret = bs58check.base58.decode(x);
      return BitcoinAddressHash(ret);
    } catch (_) {
      return null;
    }
  }

  /// Marshals [BitcoinAddressHash] as a base58-encoded string.
  @override
  String toJson() => bs58check.base58.encode(data);
}

/// Hash160, 20 bytes.
@immutable
class BitcoinAddressIdentifier extends PublicAddress {
  final Uint8List data;
  static const int size = 20;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinAddressIdentifier(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
  BitcoinAddressIdentifier.compute(BitcoinPublicKey input)
      : data = hash(input.data);

  /// Unmarshals a hex-encoded string to [BitcoinAddressIdentifier].
  BitcoinAddressIdentifier.fromJson(String x) : this(hex.decode(x));

  /// Marshals [BitcoinAddressIdentifier] as a hex-encoded string.
  @override
  String toJson() => hex.encode(data);

  /// SHA-256 then RIPEMD-160 hash.
  static Uint8List hash(Uint8List input) =>
      RIPEMD160Digest().process(SHA256Digest().process(input));
}

/// ECDSA public key, compressed with prefix byte: 33 bytes.
@immutable
class BitcoinPublicKey extends PublicAddress {
  final Uint8List data;
  static const int size = 33;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinPublicKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a hex-encoded string to [BitcoinPublicKey].
  BitcoinPublicKey.fromJson(String x) : this(hex.decode(x));

  /// Marshals [BitcoinPublicKey] as a hex-encoded string.
  @override
  String toJson() => hex.encode(data);
}

/// ECDSA private key, 32 bytes
@immutable
class BitcoinPrivateKey extends PrivateKey {
  final Uint8List data;
  final bool compressed;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinPrivateKey(this.data, [this.compressed = true]) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a WIF-encoded string to [BitcoinPrivateKey].
  BitcoinPrivateKey.fromJson(String text) : this(wif.decode(text).privateKey);

  /// Marshals [BitcoinPrivateKey] as a WIF-encoded string.
  @override
  String toJson() =>
      bs58check.encode(wif.encodeRaw(BTC.network.wif, data, compressed));

  /// Used to verify the key pair.
  BitcoinPublicKey derivePublicKey() =>
      BitcoinPublicKey(ecc.pointFromScalar(data, compressed));
}

/// ECDSA signature, 64 bytes.
@immutable
class BitcoinSignature extends Signature {
  final Uint8List data;
  static const int size = 64;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinSignature(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Decodes DER-encoded Uint8List to [BitcoinSignature].
  BitcoinSignature.fromDER(String x) : this(null);

  /// Unmarshals hex string to [BitcoinSignature].
  BitcoinSignature.fromJson(String x) : this(hex.decode(x));

  /// Marshals [BitcoinSignature] as a hex string.
  @override
  String toJson() => hex.encode(data);

  /// DER encodes [BitcoinSignature].
  String toDER() => null;
}

/// SLIP-0010 chain code.
@immutable
class BitcoinChainCode extends ChainCode {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinChainCode(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Unmarshals a hex-encoded string to [BitcoinChainCode].
  BitcoinChainCode.fromJson(String x) : this(hex.decode(x));

  /// Marshals [BitcoinChainCode] as a hex-encoded string.
  @override
  String toJson() => hex.encode(data);
}

/// Hash of the bitcoin transaction.
@immutable
class BitcoinTransactionId extends TransactionId {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinTransactionId(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Computes the hash of [transaction] - not implemented.
  BitcoinTransactionId.compute(Uint8List transaction)
      : this(Uint8List.fromList(
            BTC.doubleSha256(transaction).reversed.toList()));

  /// Unmarshals a hex string to [BitcoinTransactionId].
  BitcoinTransactionId.fromJson(String x) : this(hex.decode(x));

  /// Unmarshals a hex string (with leading zeros optionally truncated) to [BitcoinTransactionId].
  BitcoinTransactionId.fromString(String x)
      : this(zeroPadUint8List(hex.decode(zeroPadOddLengthString(x)), size));

  /// Marshals [BitcoinTransactionId] as a hex string.
  @override
  String toJson() => hex.encode(data);
}

/// Bitcoin script: https://en.bitcoin.it/wiki/Script
@immutable
class BitcoinScript {
  final Uint8List data;

  /// Fully specified constructor.
  BitcoinScript(this.data);

  /// Unmarshals a hex-encoded string to [BitcoinPublicKey].
  BitcoinScript.fromJson(String x) : this(hex.decode(x));

  /// Marshals [BitcoinScript] as a hex-encoded string.
  String toJson() => hex.encode(data);
}

/// Bitcoin transaction input: https://en.bitcoin.it/wiki/Transaction
class BitcoinTransactionInput extends TransactionInput with Serializable {
  /// True if the transaction is a coinbase.
  @override
  bool isCoinbase = false;

  // Amount of BTC from this input.
  @override
  int value;

  /// Address of sender.
  @override
  BitcoinAddressHash address;

  BitcoinTransactionId prevOut;

  int prevOutIndex;

  int sequence;

  Uint8List witness;

  /// BLOCKCHAIN API transaction index.
  int txIndex;

  /// Describes the sender.
  @override
  String get fromText =>
      isCoinbase ? 'coinbase' : (address == null ? null : address.toJson());

  /// Payment script.
  BitcoinScript script;

  /// Unmarshals a JSON-encoded string to [BitcoinTransactionInput].
  BitcoinTransactionInput.fromJson(Map<String, dynamic> json) {
    script = BitcoinScript.fromJson(json['script']);
    Map<String, dynamic> prevOut = json['prev_out'];
    if (prevOut != null) {
      value = prevOut['value'];
      String addrText = prevOut['addr'], hashText = prevOut['hash'];
      if (addrText != null) {
        address = BitcoinAddressHash.fromJson(addrText);
      }
      if (hashText != null) {
        this.prevOut = BitcoinTransactionId(hex.decode(hashText));
      }
      prevOutIndex = prevOut['n'];
    } else {
      isCoinbase = true;
      int height = json['height'];
      value = height == null ? 0 : btc.blockCreationReward(height);
    }
    sequence = json['sequence'];
    witness = hex.decode(json['witness']);
    txIndex = json['tx_index'];
  }

  /// Marshals [BitcoinTransactionInput] as a JSON-encoded string.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = {
      'script': script.toJson(),
      'prevOut': {
        'value': value,
      },
    };
    if (prevOut != null) ret['prevOut']['hash'] = prevOut.toJson();
    if (address != null) ret['prevOut']['addr'] = address.toJson();
    return ret;
  }

  @override
  int get serializedSize => 40 + BTC.varStringLength(script.data.length);

  /// Marshals [BitcoinTransactionInput] as raw bytes.
  @override
  void serialize(SerializableOutput output) {
    output.addBytes(
        prevOut != null ? prevOut.data.reversed.toList() : Uint8List(32));
    output.addUint32(prevOutIndex ?? 0xffffffff);
    BTC.serializeVarStringBytes(output, script.data);
    output.addUint32(0xffffffff);
  }

  @override
  void deserialize(SerializableInput input) {}
}

/// Bitcoin transaction output.
@JsonSerializable(includeIfNull: false)
class BitcoinTransactionOutput extends TransactionOutput with Serializable {
  // Amount of BTC to this output.
  @override
  int value;

  /// Address of recipient.
  @override
  @JsonKey(name: 'addr')
  BitcoinAddressHash address;

  /// Payment script.
  BitcoinScript script;

  /// Null constructor used by JSON deserializer.
  BitcoinTransactionOutput();

  /// Unmarshals a JSON-encoded string to [BitcoinAddress].
  factory BitcoinTransactionOutput.fromJson(Map<String, dynamic> json) =>
      _$BitcoinTransactionOutputFromJson(json);

  /// Marshals [BitcoinTransactionOutput] as a JSON-encoded string.
  Map<String, dynamic> toJson() => _$BitcoinTransactionOutputToJson(this);

  @override
  int get serializedSize => 8 + BTC.varStringLength(script.data.length);

  /// Marshals [BitcoinTransactionOutput] as raw bytes.
  @override
  void serialize(SerializableOutput output) {
    output.addUint64(value);
    BTC.serializeVarStringBytes(output, script.data);
  }

  @override
  void deserialize(SerializableInput input) {}
}

/// A ledger transaction representation. It transfers value from one address to another.
@JsonSerializable(includeIfNull: false)
class BitcoinTransaction extends Transaction with Serializable {
  /// Identifier for this transaction.
  @override
  BitcoinTransactionId hash;

  /// Currently 1.
  @JsonKey(name: 'ver')
  int version;

  /// Serialized transaction length.
  int size;

  /// Unix time.
  int time;

  /// If non-zero and sequence numbers are < 0xFFFFFFFF: block height or timestamp when transaction is final.
  @JsonKey(name: 'lock_time')
  int lockTime;

  /// BLOCKCHAIN API transaction index.
  @JsonKey(name: 'tx_index')
  int txIndex;

  /// Used by [Wallet].
  @override
  @JsonKey(name: 'block_height')
  int height = 0;

  @override
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true).toLocal();

  @override
  int get nonce => null;

  @override
  bool get isCoinbase => inputs.length == 1 && inputs[0].isCoinbase;

  /// The [PublicAddress] this transaction transfers value from.
  @override
  List<BitcoinTransactionInput> inputs;

  /// The [PublicAddress] this transaction transfers value to.
  @override
  @JsonKey(name: 'out')
  List<BitcoinTransactionOutput> outputs;

  /// Amount of value this transaction transfers in satoshis.
  @override
  int get amount => outputs.fold(0, (v, e) => v + (e.value ?? 0));

  /// The handling fee paid to the [PeerNetwork] for this transaction.
  @override
  int get fee =>
      isCoinbase ? 0 : inputs.fold(0, (v, e) => v + (e.value ?? 0)) - amount;

  /// Max 100 characters.
  @override
  String get memo => null;

  /// Block height. If set transaction can't be mined before.
  @override
  int get matures => null;

  /// Block height. If set transaction can't be mined after.
  @override
  int get expires => null;

  /// Returns true if this is a Segregated Witness transaction.
  bool get segWit =>
      inputs.isNotEmpty &&
      inputs[0].witness != null &&
      inputs[0].witness.isNotEmpty;

  /// Creates an arbitrary unsigned [BitcoinTransaction].
  BitcoinTransaction();

  /// Unmarshals a JSON-encoded string to [BitcoinTransaction].
  factory BitcoinTransaction.fromJson(Map<String, dynamic> json) =>
      _$BitcoinTransactionFromJson(json);

  /// Marshals [BitcoinTransaction] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$BitcoinTransactionToJson(this);

  /// Computes an ID for this transaction.
  @override
  BitcoinTransactionId id() =>
      BitcoinTransactionId.compute(toRaw(endian: Endian.little));

  /// Signs this transaction.
  void sign(BitcoinPrivateKey key) {}

  /// Verify only that the transaction is properly signed.
  @override
  bool verify() => false;

  @override
  int get serializedSize =>
      8 +
      inputs.fold(0, (p, c) => p + c.serializedSize) +
      outputs.fold(0, (p, c) => p + c.serializedSize) +
      BTC.varIntLength(inputs.length) +
      BTC.varIntLength(outputs.length) +
      (segWit ? (2 + inputs.fold(0, (p, c) => c.witness.length)) : 0);

  /// Marshals [BitcoinTransaction] as raw bytes.
  @override
  void serialize(SerializableOutput output) {
    bool segWit = this.segWit;
    output.addUint32(version);
    if (segWit) output.addUint16(1);
    BTC.serializeVarInt(output, inputs.length);
    for (Uint8List input in inputs.map((e) => e.toRaw(endian: Endian.little))) {
      output.addBytes(input);
    }
    BTC.serializeVarInt(output, outputs.length);
    for (Uint8List out in outputs.map((e) => e.toRaw(endian: Endian.little))) {
      output.addBytes(out);
    }
    output.addUint32(lockTime);
  }

  @override
  void deserialize(SerializableInput input) {}
}

/// Bitcoin implementation of the [Wallet] entry [Address] abstraction.
@JsonSerializable(includeIfNull: false)
class BitcoinAddress extends Address {
  // BIP32 depth.
  int chainDepth;

  /// BIP32: the fingerprint of the parent's key.
  int parentFingerprint;

  /// BIP32 key identifier.
  BitcoinAddressIdentifier identifier;

  /// The public address of this [BitcoinAddress].
  @override
  BitcoinAddressHash publicAddress;

  /// The public key of this [BitcoinAddress].
  @override
  BitcoinPublicKey publicKey;

  /// The private key for this address, if not watch-only.
  @override
  BitcoinPrivateKey privateKey;

  /// The chain code for this address, if HD derived.
  @override
  BitcoinChainCode chainCode;

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
  BitcoinAddress(this.publicKey, this.privateKey, this.chainCode,
      int chainIndex, this.chainDepth, this.parentFingerprint) {
    this.chainIndex = chainIndex;
    if (publicKey == null) {
      throw FormatException();
    }
    identifier = BitcoinAddressIdentifier.compute(publicKey);
    publicAddress = BitcoinAddressHash.compute(identifier);
  }

  /// Element of watch-only [Wallet].
  BitcoinAddress.fromAddressHash(this.publicAddress);

  /// Element of watch-only [Wallet].
  BitcoinAddress.fromPublicKey(this.publicKey) {
    identifier = BitcoinAddressIdentifier.compute(publicKey);
    publicAddress = BitcoinAddressHash.compute(identifier);
  }

  /// Element of non-HD [Wallet].
  BitcoinAddress.fromPrivateKey(this.privateKey) {
    publicKey = privateKey.derivePublicKey();
    identifier = BitcoinAddressIdentifier.compute(publicKey);
    publicAddress = BitcoinAddressHash.compute(identifier);
  }

  /// Element of HD [Wallet].
  factory BitcoinAddress.fromSeed(Uint8List seed) {
    assert(ecc.isPrivate(seed));
    return BitcoinAddress.fromPrivateKey(BitcoinPrivateKey(seed));
  }

  /// Generate a random [BitcoinAddress]. Not used by [Wallet].
  factory BitcoinAddress.generateRandom() =>
      BitcoinAddress.fromSeed(randomSeed());

  /// Unmarshals an extended public or private key to [BitcoinAddress].
  factory BitcoinAddress.fromExtendedKeyJson(String text) {
    bip32.BIP32 parsed = bip32.BIP32.fromBase58(text);
    return BitcoinAddress(
        BitcoinPublicKey(parsed.publicKey),
        parsed.privateKey == null ? null : BitcoinPrivateKey(parsed.privateKey),
        BitcoinChainCode(parsed.chainCode),
        parsed.index,
        parsed.depth,
        parsed.parentFingerprint);
  }

  /// Unmarshals a JSON-encoded string to [BitcoinAddress].
  factory BitcoinAddress.fromJson(Map<String, dynamic> json) =>
      _$BitcoinAddressFromJson(json);

  /// Marshals [BitcoinAddress] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$BitcoinAddressToJson(this);

  /// Marshals BIP32 extended private key.
  String extendedPrivateKeyJson() =>
      (bip32.BIP32(privateKey.data, publicKey.data, chainCode.data, BTC.network)
            ..depth = chainDepth
            ..index = chainIndex
            ..parentFingerprint = parentFingerprint)
          .toBase58();

  /// Marshals BIP32 extended public key.
  String extendedPublicKeyJson() => (bip32
          .BIP32(privateKey.data, publicKey.data, chainCode.data, BTC.network)
          .neutered()
            ..depth = chainDepth
            ..index = chainIndex
            ..parentFingerprint = parentFingerprint)
      .toBase58();

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
class BitcoinBlockId extends BlockId {
  final Uint8List data;
  static const int size = 32;

  /// Fully specified constructor used by JSON deserializer.
  BitcoinBlockId(this.data) {
    if (data.length != size) throw FormatException();
  }

  /// Computes the hash of [blockHeaderJson].
  BitcoinBlockId.compute(Uint8List blockHeader)
      : this(Uint8List.fromList(
            BTC.doubleSha256(blockHeader).reversed.toList()));

  /// Decodes [BigInt] to [BitcoinBlockId].
  BitcoinBlockId.fromBigInt(BigInt x)
      : this(zeroPadUint8List(encodeBigInt(x), size));

  /// Unmarshals hex string to [BitcoinBlockId].
  BitcoinBlockId.fromJson(String x) : this(hex.decode(x));

  /// Unmarshals hex string (with leading zeros optionally truncated) to [BitcoinBlockId].
  BitcoinBlockId.fromString(String x)
      : this(zeroPadUint8List(hex.decode(zeroPadOddLengthString(x)), size));

  /// Marshals [BitcoinBlockId] as a hex string.
  @override
  String toJson() => hex.encode(data);

  /// Decodes a [BigInt] representation.
  @override
  BigInt toBigInt() => decodeBigInt(data);
}

/// List of [BitcoinBlockId]
@JsonSerializable()
class BitcoinBlockIds {
  List<BitcoinBlockId> block_ids;
  BitcoinBlockIds();

  /// Unmarshals a JSON-encoded string to [BitcoinBlockIds].
  factory BitcoinBlockIds.fromJson(Map<String, dynamic> json) =>
      _$BitcoinBlockIdsFromJson(json);

  /// Marshals [BitcoinBlockIds] as a JSON-encoded string.
  Map<String, dynamic> toJson() => _$BitcoinBlockIdsToJson(this);
}

/// Data used to determine block validity and place in the block chain.
@JsonSerializable(includeIfNull: false)
class BitcoinBlockHeader extends BlockHeader with Serializable {
  // Id for this block.
  BitcoinBlockId hash;

  /// ID of the previous block in this chain.
  @override
  @JsonKey(name: 'prev_block')
  BitcoinBlockId previous;

  /// Merkle root.
  @JsonKey(name: 'mrkl_root')
  BitcoinTransactionId hashRoot;

  /// Unix time.
  int time;

  /// https://bitcoin.org/en/developer-reference#target-nbits
  int bits;

  @override
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true).toLocal();

  /// Threshold new [BitcoinBlock] must hash under for Proof of Work.
  @override
  BlockId get target {
    if (bits == null) return null;

    /// https://github.com/bitcoin/bitcoin/blob/master/src/arith_uint256.cpp#L205
    int nSize = bits >> 24, nWord = bits & 0x007fffff;
    if (nSize <= 3) {
      return BitcoinBlockId.fromBigInt(BigInt.from(nWord >> 8 * (3 - nSize)));
    } else {
      BigInt ret = BigInt.from(nWord);
      return BitcoinBlockId.fromBigInt(ret << 8 * (nSize - 3));
    }
  }

  /// Total cumulative chain work.
  BitcoinBlockId get chainWork => null;

  /// Parameter varied by miners for Proof of Work.
  int nonce;

  @override
  BigInt get nonceValue => BigInt.from(nonce);

  /// Height is eventually unique.
  @override
  int height;

  @JsonKey(name: 'ver')
  int version;

  /// The number of transactions in this block.
  @override
  @JsonKey(name: 'n_tx')
  int transactionCount;

  /// The BLOCKAIN API index of this block.
  @JsonKey(name: 'block_index')
  int blockIndex;

  /// The BLOCKAIN API index of the previous block.
  int prevBlockIndex;

  /// Default constructor used by JSON deserializer.
  BitcoinBlockHeader();

  /// Unmarshals a JSON-encoded string to [BitcoinBlockHeader].
  factory BitcoinBlockHeader.fromJson(Map<String, dynamic> json) =>
      _$BitcoinBlockHeaderFromJson(json);

  /// Marshals [BitcoinBlockHeader] as a JSON-encoded string.
  @override
  Map<String, dynamic> toJson() => _$BitcoinBlockHeaderToJson(this);

  /// Computes an ID for this block.
  @override
  BitcoinBlockId id() => BitcoinBlockId.compute(toRaw(endian: Endian.little));

  @override
  int get serializedSize => 16 + previous.data.length + hashRoot.data.length;

  /// Marshals [BitcoinBlockHeader] as raw bytes.
  @override
  void serialize(SerializableOutput output) {
    output.addUint32(version);
    output.addBytes(Uint8List.fromList(previous.data.reversed.toList()));
    output.addBytes(Uint8List.fromList(hashRoot.data.reversed.toList()));
    output.addUint32(time);
    output.addUint32(bits);
    output.addUint32(nonce);
  }

  @override
  void deserialize(SerializableInput input) {}
}

/// Represents a block in the block chain. It has a header and a list of transactions.
class BitcoinBlock extends Block {
  /// Header has [transactions] checksums and Proof of Work.
  @override
  BitcoinBlockHeader header;

  /// The list of [BitcoinTransaction] in this block of the ledger.
  @override
  List<BitcoinTransaction> transactions;

  /// List of indices representing the [BitcoinTransaction] in this block.
  List<int> txIndexes;

  /// Unmarshals a JSON-encoded string to [BitcoinBlock].
  BitcoinBlock.fromJson(Map<String, dynamic> json) {
    header = BitcoinBlockHeader.fromJson(json);
    if (json['tx'] != null) {
      transactions = json['tx']
          .map((t) => BitcoinTransaction.fromJson(t))
          .toList()
          .cast<BitcoinTransaction>();
    } else if (json['txIndexes'] != null) {
      txIndexes = json['txIndexes'].cast<int>();
    }
  }

  /// Marshals [BitcoinBlock] as a JSON-encoded string.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = header.toJson();
    ret['tx'] = transactions.map((t) => t.toJson()).toList();
    return ret;
  }

  /// Computes an ID for this block.
  @override
  BitcoinBlockId id() => header.id();

  /// Compute a Merkle tree root of all transaction hashes.
  @override
  BitcoinTransactionId computeHashRoot() => BitcoinTransactionId(MerkleTree(
          leaves: transactions.map((t) => t.hash.data).toList(),
          hashAlgo: BTC.doubleSha256,
          isBitcoinTree: true)
      .root);
}

/// Supports both Bitcoin Protocol and BLOCKCHAIN API.
class BitcoinNetwork extends PeerNetwork {
  HttpClient httpClient;

  BitcoinNetwork(this.httpClient, VoidCallback peerChanged,
      VoidCallback tipChanged, String userAgent)
      : super(peerChanged, tipChanged, userAgent: userAgent);

  @override
  BTC get currency => btc;

  @override
  List<String> get peerTypes => ['Stratum', 'BitcoinRPC', 'BlockchainAPI'];

  /// Creates [Peer] ready to [Peer.connect()].
  @override
  Peer createPeerWithSpec(PeerPreference spec) {
    Uri root = spec.root == null ? null : Uri.parse(spec.root);
    switch (spec.type) {
      case 'BlockchainAPI':
        return BlockchainAPI(
            spec, parseBlockchainInfoUri(spec.url), httpClient, root);
      case 'BitcoinRPC':
        return SupplementedBitcoinRPC(
            spec, parseBitcoinRpcUri(spec.url), httpClient, root);
      default:
        return SupplementedBitcoinPeer(
            spec, parseBitcoinUri(spec.url), httpClient, root)
          ..userAgent = userAgent;
    }
  }

  /// Valid Bitcoin URI: '10.0.0.1'.
  Uri parseBitcoinUri(String uriText) {
    if (!Uri.parse(uriText).hasScheme) uriText = 'bitcoin://' + uriText;
    Uri uri = Uri.parse(uriText);
    return uri.replace(port: uri.hasPort ? uri.port : 8333);
  }

  /// Valid Bitcoin RPC URI: '10.0.0.1'.
  Uri parseBitcoinRpcUri(String uriText) {
    if (!Uri.parse(uriText).hasScheme) uriText = 'http://' + uriText;
    Uri uri = Uri.parse(uriText);
    return uri.replace(port: uri.hasPort ? uri.port : 8332);
  }

  /// Valid Blockchain URI: 'ws.blockchain.info', 'wss://ws.blockchain.info/inv'.
  Uri parseBlockchainInfoUri(String uriText) {
    if (!Uri.parse(uriText).hasScheme) uriText = 'wss://' + uriText;
    Uri uri = Uri.parse(uriText);
    return uri.replace(path: uri.path.isEmpty ? '/inv' : uri.path);
  }
}

/// Supplements with Blockchain.info for historical transaction information.
/// Bitcoin protocol is used for the rest.
class SupplementedBitcoinPeer extends BitcoinPeer
    with HttpClientMixin, SupplementalBlockchainAPI {
  SupplementedBitcoinPeer(PeerPreference spec, Uri webSocketAddress,
      HttpClient httpClient, Uri httpAddress)
      : super(spec, webSocketAddress) {
    this.httpClient = httpClient;
    this.httpAddress = httpAddress;
    responseComplete = dispatchFromThrottleQueue;
  }

  /// Throttles sum of outstanding Bitcoin Protocol and Blockchain API calls.
  int get numOutstanding => rawResponseQueue.length + httpClient.numOutstanding;
}

/// Supplements with Blockchain.info for historical transaction information.
/// Bitcoin RPC is used for the rest.
class SupplementedBitcoinRPC extends BitcoinRPC
    with HttpClientMixin, SupplementalBlockchainAPI {
  SupplementedBitcoinRPC(PeerPreference spec, Uri webSocketAddress,
      HttpClient httpClient, Uri httpAddress)
      : super(spec, webSocketAddress, httpClient) {
    this.httpClient = httpClient;
    this.httpAddress = httpAddress;
    responseComplete = dispatchFromThrottleQueue;
  }

  /// Throttles sum of outstanding Bitcoin RPC and Blockchain API calls.
  int get numOutstanding =>
      peerClient.numOutstanding + httpClient.numOutstanding;
}

/// Bitcoin implementation of the [PeerNetwork] entry [Peer] abstraction.
/// Reference: https://en.bitcoin.it/wiki/Protocol_documentation
class BitcoinPeer extends PersistentSocketClient with RawResponseQueueMixin {
  /// The [BitcoinAddress] we're monitoring [BitcoinNetwork] for.
  Map<String, TransactionCallback> addressFilter =
      Map<String, TransactionCallback>();

  /// Height of tip [BitcoinBlock] according to this peer.
  @override
  int tipHeight;

  /// ID of tip [BitcoinBlock] according to this peer.
  @override
  BitcoinBlockId tipId;

  /// The minimum [BitcoinTransaction.amount] for the [BitcoinNetwork].
  @override
  num minAmount;

  /// The minimum [BitcoinTransaction.fee] for the [BitcoinNetwork].
  @override
  num minFee;

  QueueBuffer messageBuffer = QueueBuffer(Uint8List(0));

  /// Forward [Peer] constructor.
  BitcoinPeer(PeerPreference spec, Uri uri) : super(spec, uri);

  /// Network lost. Clear [tip] and [tipId].
  @override
  void handleDisconnected() {
    addressFilter = Map<String, TransactionCallback>();
    tipId = null;
    tipHeight = null;
  }

  /// BeNetwork connected. Request [tip] and subscribe to new blocks.
  @override
  void handleConnected() {
    int ver = 60000;
    addMessage(VersionMessage(
        ver,
        0,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        BitcoinNetworkAddress(),
        BitcoinNetworkAddress(),
        70723,
        'useragent',
        0,
        false));
  }

  /// https://en.bitcoin.it/wiki/Protocol_documentation#Message_structure
  void addMessage(BitcoinMessage command, [RawCallback responseCallback]) {
    Uint8List message = command.toBytes();
    socket.sendRaw(message);
    addOutstandingRaw(message, responseCallback);
  }

  /// Impossible to get balance with Bitcoin Protocol.
  @override
  Future<num> getBalance(PublicAddress address) => Future.value(0);

  /// Impossible to get transactions with Bitcoin Protocol.
  @override
  Future<TransactionIteratorResults> getTransactions(
          PublicAddress address, TransactionIterator iterator,
          {int limit = 50}) =>
      Future.value(TransactionIteratorResults.empty());

  @override
  Future<TransactionId> putTransaction(Transaction transaction) {
    return null;
  }

  /// Subscribing to an Address
  /// Receive new transactions for a specific bitcoin address:
  /// {"op":"addr_sub", "addr":"$bitcoin_address"}
  @override
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb) {
    return Future.value(false);
  }

  @override
  Future<bool> filterTransactionQueue() {
    /// https://blockchain.info/unconfirmed-transactions?format=json
    return Future.value(true);
  }

  @override
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height}) {
    /// No way to only fetch header with blockchain API??
    return null;
  }

  /// Blocks for one day: https://blockchain.info/blocks/$time_in_milliseconds?format=json
  Future<List<BitcoinBlockHeader>> getBlockHeaders(DateTime time) {
    return null;
  }

  /// Single Block
  /// You can also request the block to return in binary form (Hex encoded) using ?format=hex
  @override
  Future<BlockMessage> getBlock({BlockId id, int height}) {
    return null;
  }

  /// Single Transaction
  /// You can also request the transaction to return in binary form (Hex encoded) using ?format=hex
  @override
  Future<TransactionMessage> getTransaction(TransactionId id) {
    return null;
  }

  /// Handle Bitcoin Protocol.
  void handleMessage(Uint8List message) {
    messageBuffer.add(message);
    while (messageBuffer.data.length >= BitcoinMessage.messageHeaderLength) {
      SerializableInput input = SerializableInput(
          viewUint8List(message, 0, BitcoinMessage.messageHeaderLength),
          endian: Endian.little);
      int magic = input.getUint32();
      Uint8List command = input.getBytes(12);
      int payloadLength = input.getUint32();

      Uint8List checksum = input.getBytes(4);
      if (messageBuffer.data.length <
          payloadLength + BitcoinMessage.messageHeaderLength) break;
      input = SerializableInput(viewUint8List(
          message, BitcoinMessage.messageHeaderLength, payloadLength));
      handleCommand(command, input);
      messageBuffer.flush(BitcoinMessage.messageHeaderLength + payloadLength);
    }
  }

  void handleCommand(Uint8List commandBytes, SerializableInput input) {
    int length = 0;
    while (commandBytes.length > length && commandBytes[length] != 0) length++;
    if (length == 0) {
      if (spec.debugPrint != null) {
        spec.debugPrint('invalid command $commandBytes');
      }
      return;
    }
    String command =
        String.fromCharCodes(viewUint8List(commandBytes, 0, length));
    if (spec.debugPrint != null) {
      spec.debugPrint('BTC command: $command');
    }
  }

  /// Handles every new [BitcoinBlock] on the [BitcoinNetwork].
  /// [BitcoinBlock.transactions] is empty if no [BitcoinTransaction] match our [filterAdd()].
  void handleFilterBlock(BitcoinBlockId id, BitcoinBlock block, bool undo) {}

  /// Handles every new [BitcoinTransaction] matching our [filterAdd()]
  void handleNewTransaction(BitcoinTransaction transaction) {}
}

/// Bitcoin RPC implementation of the [PeerNetwork] entry [Peer] abstraction.
/// Reference: https://bitcoincore.org/en/doc/0.18.0/
class BitcoinRPC extends HttpClientPeer {
  /// The [BitcoinAddress] we're monitoring [BitcoinNetwork] for.
  Map<String, TransactionCallback> addressFilter =
      Map<String, TransactionCallback>();

  /// Height of tip [BitcoinBlock] according to this peer.
  @override
  int tipHeight;

  /// ID of tip [BitcoinBlock] according to this peer.
  @override
  BitcoinBlockId tipId;

  /// The minimum [BitcoinTransaction.amount] for the [BitcoinNetwork].
  @override
  num minAmount;

  /// The minimum [BitcoinTransaction.fee] for the [BitcoinNetwork].
  @override
  num minFee;

  /// Forward [Peer] constructor.
  BitcoinRPC(PeerPreference spec, Uri uri, HttpClient httpClient)
      : super(spec, uri, httpClient) {
    //responseComplete = dispatchFromThrottleQueue;
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
    peerClient
        .request(
      '$address',
      method: 'POST',
      data: jsonEncode(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'getinfo',
      }),
      headers: (spec.user != null && spec.password != null)
          ? addBasicAuthenticationHeader(
              Map<String, String>(), spec.user, spec.password)
          : null,
    )
        .then(
      (resp) {
        print('got resp ${resp.status} ${resp.text}');
      },
    );
  }

  /// Balance: List the balance summary of each address listed.
  @override
  Future<num> getBalance(PublicAddress address) {
    return Future.value(0);
  }

  @override
  Future<TransactionIteratorResults> getTransactions(
      PublicAddress address, TransactionIterator iterator,
      {int limit = 50}) {
    return null;
  }

  @override
  Future<TransactionId> putTransaction(Transaction transaction) {
    return null;
  }

  /// Subscribing to an Address
  /// Receive new transactions for a specific bitcoin address:
  /// {"op":"addr_sub", "addr":"$bitcoin_address"}
  @override
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb) {
    return Future.value(false);
  }

  @override
  Future<bool> filterTransactionQueue() {
    /// https://blockchain.info/unconfirmed-transactions?format=json
    return Future.value(true);
  }

  @override
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height}) {
    /// No way to only fetch header with blockchain API??
    return null;
  }

  /// Blocks for one day: https://blockchain.info/blocks/$time_in_milliseconds?format=json
  Future<List<BitcoinBlockHeader>> getBlockHeaders(DateTime time) {
    return null;
  }

  /// Single Block
  /// You can also request the block to return in binary form (Hex encoded) using ?format=hex
  @override
  Future<BlockMessage> getBlock({BlockId id, int height}) {
    return null;
  }

  /// Estimated network hash rate.
  Future<int> getHashRate({BlockId id, int height}) {
    return null;
  }

  /// Single Transaction
  /// You can also request the transaction to return in binary form (Hex encoded) using ?format=hex
  @override
  Future<TransactionMessage> getTransaction(TransactionId id) {
    return null;
  }

  /// Handle the BLOCKCHAIN WebSocket API message frame consisting of [op] and [x].
  void handleMessage(Uint8List messageBytes) {
    String message = utf8.decode(messageBytes);
  }

  /// Handles every new [BitcoinBlock] on the [BitcoinNetwork].
  /// [BitcoinBlock.transactions] is empty if no [BitcoinTransaction] match our [filterAdd()].
  void handleFilterBlock(BitcoinBlockId id, BitcoinBlock block, bool undo) {}

  /// Handles every new [BitcoinTransaction] matching our [filterAdd()]
  void handleNewTransaction(BitcoinTransaction transaction) {}
}

/// Provides [getBalance()], [getUnspentOutputs], and [getAddressTransactions].
mixin SupplementalBlockchainAPI on HttpClientMixin {
  /// Balance: List the balance summary of each address listed.
  Future<num> getBalance(PublicAddress address) {
    Completer<num> completer = Completer<num>();
    String addressText = address.toJson();

    /// [addressText] can be base58 or xpub.
    /// Multiple Addresses Allowed separated by "|".
    httpClient.request('$httpAddress/balance?active=$addressText').then((resp) {
      Map<String, dynamic> data = jsonDecode(resp.text);
      Map<String, dynamic> addr = data == null ? null : data[addressText];
      completeResponse(completer, addr == null ? null : addr['final_balance']);
    });
    return completer.future;
  }

  Future<TransactionIteratorResults> getTransactions(
      PublicAddress address, TransactionIterator iterator,
      {int limit = 50}) {
    return getAddressTransactions(address,
        offset: iterator != null ? iterator.index : 0, limit: limit);
  }

  /// Single Address
  Future<TransactionIteratorResults> getAddressTransactions(
      PublicAddress address,
      {int offset = 0,
      int limit = 50}) {
    Completer<TransactionIteratorResults> completer =
        Completer<TransactionIteratorResults>();
    String addressText = address.toJson();

    /// [addressText] can be base58 or hash160
    /// Optional limit parameter to show n transactions e.g. &limit=50 (Default: 50, Max: 50)
    /// Optional offset parameter to skip the first n transactions e.g. &offset=100 (Page 2 for limit 50)
    httpClient
        .request(
            '$httpAddress/rawaddr/$addressText?offset=$offset&limit=$limit')
        .then((resp) {
      Map<String, dynamic> data = resp == null ? null : jsonDecode(resp.text);
      var txs = data == null ? null : data['txs'];
      if (txs == null) {
        completeResponse(completer, null);
        return;
      }
      checkEquals(addressText, data['address'], httpClient.debugPrint);

      TransactionIteratorResults ret =
          TransactionIteratorResults(0, offset + limit, List<Transaction>());
      for (var t in txs) {
        ret.transactions.add(BitcoinTransaction.fromJson(t));
      }

      completeResponse(completer, ret);
    });
    return completer.future;
  }
}

/// Blockchain.info implementation of the [PeerNetwork] entry [Peer] abstraction.
/// Reference: https://www.blockchain.com/api/api_websocket
class BlockchainAPI extends PersistentSocketClient
    with HttpClientMixin, SupplementalBlockchainAPI, NullJsonResponseMixin {
  /// The [BitcoinAddress] we're monitoring [BitcoinNetwork] for.
  Map<String, TransactionCallback> addressFilter =
      Map<String, TransactionCallback>();

  /// Height of tip [BitcoinBlock] according to this peer.
  @override
  int tipHeight;

  /// ID of tip [BitcoinBlock] according to this peer.
  @override
  BitcoinBlockId tipId;

  /// The minimum [BitcoinTransaction.amount] for the [BitcoinNetwork].
  @override
  num minAmount;

  /// The minimum [BitcoinTransaction.fee] for the [BitcoinNetwork].
  @override
  num minFee;

  /// Forward [Peer] constructor.
  BlockchainAPI(PeerPreference spec, Uri webSocketAddress,
      HttpClient httpClient, Uri httpAddress)
      : super(spec, webSocketAddress) {
    this.httpClient = httpClient;
    this.httpAddress = httpAddress;
    responseComplete = dispatchFromThrottleQueue;
    maxOutstanding = 10;
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
    // Subscribing to new Blocks
    // Receive notifications when a new block is found. Note: if the chain splits you will receive more than one notification for a specific block height.
    addJsonMessage(
      <String, dynamic>{
        'op': 'blocks_sub',
      },
    );

    addJsonMessage(
      <String, dynamic>{
        'op': 'ping_block',
      },
    );
  }

  @override
  Future<TransactionId> putTransaction(Transaction transaction) {
    Completer<TransactionId> completer = Completer<TransactionId>();

    httpClient
        .request(
      '$httpAddress/pushtx?cors=true',
      method: 'POST',
      data: jsonEncode(transaction),
      /*headers: {'Content-Type', 'application/x-www-form-urlencoded'}*/
    )
        .then((resp) {
      completeResponse(completer, null);
    });
    return completer.future;
  }

  /// Subscribing to an Address
  /// Receive new transactions for a specific bitcoin address:
  /// {"op":"addr_sub", "addr":"$bitcoin_address"}
  @override
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb) {
    addressFilter[address.toJson()] = transactionCb;
    addJsonMessage(
      <String, dynamic>{
        'op': 'addr_sub',
        'addr': address.toJson(),
      },
    );
    return Future.value(true);
  }

  @override
  Future<bool> filterTransactionQueue() {
    /// https://blockchain.info/unconfirmed-transactions?format=json
    return Future.value(true);
  }

  @override
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height}) {
    /// No way to only fetch header with blockchain API??
    return null;
  }

  /// Blocks for one day: https://blockchain.info/blocks/$time_in_milliseconds?format=json
  Future<List<BitcoinBlockHeader>> getBlockHeaders(DateTime time) {
    Completer<List<BitcoinBlockHeader>> completer =
        Completer<List<BitcoinBlockHeader>>();
    httpClient
        .request(
            '$httpAddress/blocks/${time.toUtc().millisecondsSinceEpoch}?format=json')
        .then(
      (resp) {
        Map<String, dynamic> data = resp == null ? null : jsonDecode(resp.text);
        var blocks = data == null ? null : data['blocks'];
        if (blocks == null) {
          completeResponse(completer, null);
          return;
        }
        completeResponse(
            completer,
            blocks
                .map((h) => BitcoinBlockHeader.fromJson(h))
                .toList()
                .cast<BitcoinBlockHeader>());
      },
    );
    return completer.future;
  }

  /// Single Block
  /// You can also request the block to return in binary form (Hex encoded) using ?format=hex
  @override
  Future<BlockMessage> getBlock({BlockId id, int height}) {
    Completer<BlockMessage> completer = Completer<BlockMessage>();
    httpClient
        .request('$httpAddress' +
            (id != null
                ? '/rawblock/${id.toJson()}'
                : '/block-height/$height?format=json'))
        .then(
      (resp) {
        Map<String, dynamic> data = resp == null ? null : jsonDecode(resp.text);
        var blocks = data == null ? null : data['blocks'];
        var block = blocks == null ? null : blocks.first;
        if (block == null) {
          completeResponse(completer, null);
          return;
        }
        completeResponse(
            completer,
            BlockMessage(BitcoinBlockId.fromJson(block['hash']),
                block != null ? BitcoinBlock.fromJson(block) : null));
      },
    );
    return completer.future;
  }

  /// Estimated network hash rate.
  Future<int> getHashRate({BlockId id, int height}) {
    Completer<int> completer = Completer<int>();
    httpClient.request('$httpAddress/q/hashrate?format=json').then((resp) {
      int rate = jsonDecode(resp.text);
      completeResponse(
          completer,
          rate == null
              ? null
              : (BigInt.from(rate) * BigInt.from(1000000000)).toInt());
    });
    return completer.future;
  }

  /// Single Transaction
  /// You can also request the transaction to return in binary form (Hex encoded) using ?format=hex
  @override
  Future<TransactionMessage> getTransaction(TransactionId id) {
    Completer<TransactionMessage> completer = Completer<TransactionMessage>();
    httpClient.request('$httpAddress/rawtx/${id.toJson()}').then(
      (resp) {
        Map<String, dynamic> transaction =
            resp == null ? null : jsonDecode(resp.text);
        if (transaction == null) {
          completeResponse(completer, null);
          return;
        }
        TransactionMessage ret = TransactionMessage(
            id,
            transaction != null
                ? BitcoinTransaction.fromJson(transaction)
                : null);
        completeResponse(completer, ret);
      },
    );
    return completer.future;
  }

  /// Handle the BLOCKCHAIN WebSocket API message frame consisting of [op] and [x].
  void handleMessage(Uint8List messageBytes) {
    String message = utf8.decode(messageBytes);
    if (spec.debugPrint != null && spec.debugLevel >= debugLevelDebug) {
      debugPrintLong('got blockchain API message ' + message, spec.debugPrint);
    }
    Map<String, dynamic> json = jsonDecode(message);
    Map<String, dynamic> x = json['x'];
    switch (json['op']) {
      case 'block':
        handleProtocol(() => handleFilterBlock(
            BitcoinBlockId.fromJson(x['hash']),
            BitcoinBlock.fromJson(renameBlockJsonFromWebSocketAPI(x)),
            false));
        break;
      case 'utx':
        handleProtocol(
            () => handleNewTransaction(BitcoinTransaction.fromJson(x)));
        break;
      default:
        break;
    }
  }

  /// Handles every new [BitcoinBlock] on the [BitcoinNetwork].
  /// [BitcoinBlock.transactions] is empty if no [BitcoinTransaction] match our [filterAdd()].
  void handleFilterBlock(BitcoinBlockId id, BitcoinBlock block, bool undo) {
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
      for (BitcoinTransaction transaction in block.transactions) {
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

  /// Handles every new [BitcoinTransaction] matching our [filterAdd()]
  void handleNewTransaction(BitcoinTransaction transaction) {
    for (BitcoinTransactionInput input in transaction.inputs) {
      if (input.fromText == null) continue;
      TransactionCallback cb = addressFilter[input.fromText];
      if (cb != null) {
        cb(transaction);
        return;
      }
    }
    for (BitcoinTransactionOutput output in transaction.outputs) {
      if (output.toText == null) continue;
      TransactionCallback cb = addressFilter[output.toText];
      if (cb != null) {
        cb(transaction);
        return;
      }
    }
  }

  Map<String, dynamic> renameBlockJsonFromWebSocketAPI(
      Map<String, dynamic> data) {
    data['block_index'] = data['blockIndex'];
    data['mrkl_root'] = data['mrklRoot'];
    data['n_tx'] = data['nTx'];
    return data;
  }
}

/// https://en.bitcoin.it/wiki/Protocol_documentation#Message_structure
abstract class BitcoinMessage extends Serializable {
  String get command;

  static int messageHeaderLength = 24;

  Uint8List toBytes() {
    Uint8List commandBytes = Uint8List(12);
    commandBytes.setRange(0, min(11, command.length), command.codeUnits);
    Uint8List payload = toRaw(endian: Endian.little);
    Uint8List message =
        Uint8List.fromList(Uint8List(messageHeaderLength) + payload);

    SerializableOutput output =
        SerializableOutput(message, endian: Endian.little);
    output.addUint32(0xD9B4BEF9);
    output.addBytes(commandBytes);
    output.addUint32(payload.length);
    output.addBytes(viewUint8List(BTC.doubleSha256(payload), 0, 4));
    output.addBytes(payload);
    assert(output.done);
    return message;
  }
}

/// When a network address is needed somewhere, this structure is used.
/// Network addresses are not prefixed with a timestamp in the version message.
class BitcoinNetworkAddress extends Serializable {
  int version, timestamp, services = 0, port = 0;
  Uint8List ipv6Address = Uint8List(16);
  BitcoinNetworkAddress([this.version]);

  @override
  int get serializedHeaderSize => 26;

  @override
  int get serializedSize =>
      serializedHeaderSize + ((version ?? 0) >= 31402 ? 4 : 0);

  @override
  void serialize(SerializableOutput output) {
    if ((version ?? 0) >= 31402) {
      output.addUint32(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    }
    output.addUint64(services);
    output.addBytes(ipv6Address);
    output.addUint16(port);
  }

  @override
  void deserialize(SerializableInput input) {
    if ((version ?? 0) >= 31402) {
      timestamp = input.getUint32();
    }
    services = input.getUint64();
    ipv6Address = input.getBytes(16);
    port = input.getUint16();
  }
}

/// When a node creates an outgoing connection, it will immediately advertise its version.
/// The remote node will respond with its version. No further communication is possible until
/// both peers have exchanged their version.
class VersionMessage extends BitcoinMessage {
  VersionMessage(
      [this.version,
      this.services,
      this.timestamp,
      this.addrRecv,
      this.addrFrom,
      this.nonce,
      this.userAgent,
      this.startHeight,
      this.relay]);

  /// Identifies protocol version being used by the node.
  int version;

  /// bitfield of features to be enabled for this connection.
  int services;

  /// standard UNIX timestamp in seconds.
  int timestamp;

  /// The network address of the node receiving this message.
  BitcoinNetworkAddress addrRecv;

  /// The network address of the node emitting this message.
  BitcoinNetworkAddress addrFrom;

  /// Node random nonce, randomly generated every time a version packet is sent. This nonce is used to detect connections to self.
  int nonce;

  /// User Agent (0x00 if string is 0 bytes long).
  String userAgent;

  /// The last block received by the emitting node.
  int startHeight;

  /// Whether the remote peer should announce relayed transactions or not, see BIP 0037.
  bool relay;

  @override
  String get command => 'version';

  @override
  int get serializedHeaderSize => 20 + 26;

  @override
  int get serializedSize =>
      serializedHeaderSize +
      (version >= 106 ? 16 + 26 + BTC.varStringLength(userAgent.length) : 0) +
      (version >= 70001 ? 1 : 0);

  @override
  void serialize(SerializableOutput output) {
    output.addUint32(version);
    output.addUint64(services);
    output.addUint64(timestamp);
    addrRecv.serialize(output);
    if (version >= 106) {
      addrFrom.serialize(output);
      output.addUint64(nonce);
      BTC.serializeVarString(output, userAgent);
      output.addUint64(startHeight);
    }
    if (version >= 70001) {
      output.addUint8(relay ? 1 : 0);
    }
  }

  @override
  void deserialize(SerializableInput input) {
    version = input.getUint32();
    services = input.getUint64();
    timestamp = input.getUint64();
    addrRecv.deserialize(input);
    if (version >= 106) {
      addrFrom.deserialize(input);
      nonce = input.getUint64();
      userAgent = BTC.deserializeVarString(input);
      startHeight = input.getUint64();
    }
    if (version >= 70001) {
      relay = input.getUint8() != 0;
    }
  }
}

/// The first [BitcoinBlock] in the chain: https://blockchain.info/rawblock/000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
const String genesisBlockJson = '''{
    "hash":"000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    "ver":1,
    "prev_block":"0000000000000000000000000000000000000000000000000000000000000000",
    "next_block": [
        "00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048"
    ],
    "mrkl_root":"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
    "time":1231006505,
    "bits":486604799,
    "fee":0,
    "nonce":2083236893,
    "n_tx":1,
    "size":285,
    "block_index":14849,
		"main_chain":true,
    "height":0,
    "tx":[
        {
            "lock_time":0,
            "ver":1,
            "size":204,
            "inputs":[
               {
                  "sequence":4294967295,
                  "witness":"",
                  "script":"04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73"
               }
            ],
            "weight":816,
            "time":1231006505,
            "tx_index":14849,
            "vin_sz":1,
            "hash":"4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
            "vout_sz":1,
            "relayed_by":"0.0.0.0",
            "out":[
               {
                  "addr_tag_link":"https:\/\/en.bitcoin.it\/wiki\/Genesis_block",
                  "addr_tag":"Genesis of Bitcoin",
                  "spent":false,
                  "tx_index":14849,
                  "type":0,
                  "addr":"1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
                  "value":5000000000,
                  "n":0,
                  "script":"4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac"
               }
            ]
        }
    ]
}
''';
