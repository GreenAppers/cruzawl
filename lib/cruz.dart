// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import "package:convert/convert.dart";
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:json_annotation/json_annotation.dart';
import "package:pointycastle/digests/sha256.dart";
import "package:pointycastle/src/utils.dart";
import 'package:tweetnacl/tweetnacl.dart' as tweetnacl;

import 'package:cruzawl/sha3.dart';
import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/util.dart';
import 'package:cruzawl/websocket.dart';

part 'cruz.g.dart';

class CRUZ extends Currency {
  static const int cruzbitsPerCruz = 100000000;
  static const int blocksUntilNewSeries = 1008; // 1 week in blocks
  static const int coinbaseMaturity = 100;

  @override
  String get ticker => 'CRUZ';

  @override
  int get bip44CoinType => 831;

  @override
  String format(num v) =>
      v != null ? (v / cruzbitsPerCruz).toStringAsFixed(2) : '0';

  @override
  String formatTime(int time) =>
      DateTime.fromMillisecondsSinceEpoch(time * 1000).toString();

  @override
  String suggestedFee(Transaction t) => '0.01';

  @override
  num parse(String v) {
    num x = num.tryParse(v);
    return x != null ? (x * cruzbitsPerCruz).floor() : 0;
  }

  @override
  CruzPeerNetwork network = CruzPeerNetwork();

  @override
  PublicAddress get nullAddress => CruzPublicKey(Uint8List(32));

  @override
  String genesisBlockId() =>
      CruzBlock.fromJson(jsonDecode(genesisBlockJson)).id().toJson();

  @override
  CruzAddress deriveAddress(Uint8List seed, String path,
      [StringCallback debugPrint]) {
    KeyData data = ED25519_HD_KEY.derivePath(path, hex.encode(seed));
    Uint8List publicKey = ED25519_HD_KEY.getBublickKey(data.key, false);
    if (debugPrint != null)
      debugPrint('deriveAddress($path) = ${base64.encode(publicKey)}');
    return CruzAddress(
        CruzPublicKey(publicKey),
        CruzPrivateKey(Uint8List.fromList(data.key + publicKey)),
        CruzChainCode(data.chainCode));
  }

  @override
  CruzAddress fromPublicKey(PublicAddress addr) {
    CruzPublicKey key = CruzPublicKey.fromJson(addr.toJson());
    return CruzAddress.fromPublicKey(key);
  }

  @override
  CruzAddress fromPrivateKey(PrivateKey key) => CruzAddress.fromPrivateKey(key);

  @override
  CruzAddress fromAddressJson(Map<String, dynamic> json) =>
      CruzAddress.fromJson(json);

  @override
  PublicAddress fromPublicAddressJson(String text) {
    try {
      Uint8List data = base64.decode(text);
      if (data.length != CruzPublicKey.size) return null;
      return CruzPublicKey(data);
    } on Exception {
      return null;
    }
  }

  @override
  PrivateKey fromPrivateKeyJson(String text) => CruzPrivateKey.fromJson(text);

  TransactionId fromTransactionIdJson(String text) =>
      CruzTransactionId.fromJson(text);

  @override
  Transaction fromTransactionJson(Map<String, dynamic> json) =>
      CruzTransaction.fromJson(json);

  @override
  Transaction signedTransaction(Address fromInput, PublicAddress toInput,
      num amount, num fee, String memo, int height,
      {int matures, int expires}) {
    if (!(fromInput is CruzAddress)) throw FormatException();
    if (!(toInput is CruzPublicKey)) throw FormatException();
    CruzAddress from = fromInput;
    CruzPublicKey to = toInput;
    return CruzTransaction(from.publicKey, to, amount, fee, memo,
        matures: matures, expires: expires, height: height)
      ..sign(from.privateKey);
  }
}

class CruzPublicKey extends PublicAddress {
  final Uint8List data;
  static const int size = 32;

  CruzPublicKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  CruzPublicKey.fromJson(String x) : this(base64.decode(x));

  @override
  String toJson() => base64.encode(data);
}

class CruzPrivateKey extends PrivateKey {
  final Uint8List data;
  static const int size = 64;

  CruzPrivateKey(this.data) {
    if (data.length != size) throw FormatException();
  }

  CruzPrivateKey.fromJson(String x) : this(base64.decode(x));

  @override
  String toJson() => base64.encode(data);

  CruzPublicKey getPublicKey() =>
      CruzPublicKey(data.buffer.asUint8List(size - CruzPublicKey.size));

  CruzPublicKey derivePublicKey() => CruzPublicKey(
      tweetnacl.Signature.keyPair_fromSeed(data.buffer.asUint8List(0, 32))
          .publicKey);
}

class CruzSignature extends Signature {
  final Uint8List data;
  static const int size = 64;

  CruzSignature(this.data) {
    if (data.length != size) throw FormatException();
  }

  CruzSignature.fromJson(String x) : this(base64.decode(x));

  String toJson() => base64.encode(data);
}

class CruzChainCode extends ChainCode {
  final Uint8List data;
  static const int size = 32;

  CruzChainCode(this.data) {
    if (data.length != size) throw FormatException();
  }

  CruzChainCode.fromJson(String x) : this(base64.decode(x));

  @override
  String toJson() => base64.encode(data);
}

class CruzTransactionId extends TransactionId {
  final Uint8List data;
  static const int size = 32;

  CruzTransactionId(this.data) {
    if (data.length != size) throw FormatException();
  }

  CruzTransactionId.compute(String x)
      : data = SHA3Digest(256).process(utf8.encode(x));

  CruzTransactionId.fromJson(String x) : this(hex.decode(x));

  @override
  String toJson() => hex.encode(data);
}

@JsonSerializable(includeIfNull: false)
class CruzTransaction extends Transaction {
  int time;
  int nonce;
  CruzPublicKey from;
  CruzPublicKey to;
  int amount;
  int fee;
  String memo;
  int matures;
  int expires;
  int series;
  CruzSignature signature;

  @JsonKey(ignore: true)
  int height = 0;

  @override
  String get fromText => from != null ? from.toJson() : 'cruzbase';

  CruzTransaction(this.from, this.to, this.amount, this.fee, this.memo,
      {this.matures, this.expires, this.series, this.height})
      : time = DateTime.now().millisecondsSinceEpoch ~/ 1000,
        nonce = Random.secure().nextInt(2147483647) {
    if (series == null) series = computeTransactionSeries(from == null, height);
    if (memo != null && memo.isEmpty) memo = null;
  }

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

  factory CruzTransaction.fromJson(Map<String, dynamic> json) =>
      _$CruzTransactionFromJson(json);

  @override
  Map<String, dynamic> toJson() => signedJson();

  Map<String, dynamic> signedJson() => _$CruzTransactionToJson(this);

  Map<String, dynamic> unsignedJson() => signature == null
      ? _$CruzTransactionToJson(this)
      : _$CruzTransactionToJson(CruzTransaction.withoutSignature(this));

  @override
  CruzTransactionId id() =>
      CruzTransactionId.compute(jsonEncode(unsignedJson()));

  void sign(CruzPrivateKey key) =>
      signature = CruzSignature(tweetnacl.Signature(null, key.data)
          .sign(id().data)
          .buffer
          .asUint8List(0, 64));

  @override
  bool verify() => signature == null
      ? false
      : tweetnacl.Signature(from.data, null)
          .detached_verify(id().data, signature.data);

  static int computeTransactionSeries(bool isCoinbase, int height) {
    if (isCoinbase) {
      // coinbases start using the new series right on time
      return height ~/ CRUZ.blocksUntilNewSeries + 1;
    }

    // otherwise don't start using a new series until 100 blocks in to mitigate
    // potential reorg issues right around the switchover
    return (height - 100) ~/ CRUZ.blocksUntilNewSeries + 1;
  }
}

@JsonSerializable(includeIfNull: false)
class CruzAddress extends Address {
  @override
  CruzPublicKey publicKey;

  @override
  CruzPrivateKey privateKey;

  @override
  CruzChainCode chainCode;

  @JsonKey(ignore: true)
  int maturesHeight = 0;

  @JsonKey(ignore: true)
  int loadedHeight;

  @JsonKey(ignore: true)
  int loadedIndex;

  @JsonKey(ignore: true)
  num maturesBalance = 0;

  @JsonKey(ignore: true)
  num newBalance;

  @JsonKey(ignore: true)
  num newMaturesBalance;

  CruzAddress(this.publicKey, this.privateKey, this.chainCode) {
    if (publicKey == null ||
        (privateKey != null &&
            !equalUint8List(publicKey.data, privateKey.getPublicKey().data)))
      throw FormatException();
  }

  CruzAddress.fromPublicKey(this.publicKey);

  CruzAddress.fromPrivateKey(this.privateKey) {
    publicKey = privateKey.getPublicKey();
  }

  CruzAddress.generateRandom()
      : this.fromSeed(SHA256Digest().process(randBytes(32)));

  CruzAddress.fromSeed(Uint8List seed) {
    tweetnacl.KeyPair pair = tweetnacl.Signature.keyPair_fromSeed(seed);
    publicKey = CruzPublicKey(pair.publicKey);
    privateKey = CruzPrivateKey(pair.secretKey);
  }

  factory CruzAddress.fromJson(Map<String, dynamic> json) =>
      _$CruzAddressFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CruzAddressToJson(this);

  bool verify() =>
      privateKey != null &&
      equalUint8List(
          privateKey.getPublicKey().data, privateKey.derivePublicKey().data);
}

class CruzBlockId extends BlockId {
  final Uint8List data;
  static const int size = 32;

  CruzBlockId(this.data) {
    if (data.length != size) throw FormatException();
  }

  CruzBlockId.compute(String x)
      : data = SHA3Digest(256).process(utf8.encode(x));

  CruzBlockId.fromJson(String x) : data = hex.decode(x) {
    if (data.length != size) throw FormatException('input=${x}');
  }

  @override
  String toJson() => hex.encode(data);
}

@JsonSerializable()
class CruzBlockIds {
  List<CruzBlockId> ids;
  CruzBlockIds();

  factory CruzBlockIds.fromJson(Map<String, dynamic> json) =>
      _$CruzBlockIdsFromJson(json);

  Map<String, dynamic> toJson() => _$CruzBlockIdsToJson(this);
}

@JsonSerializable()
class CruzBlockHeader extends BlockHeader {
  @override
  CruzBlockId previous;

  @JsonKey(name: 'hash_list_root')
  CruzTransactionId hashListRoot;

  @override
  int time;

  @override
  CruzBlockId target;

  @JsonKey(name: 'chain_work')
  CruzBlockId chainWork;

  @override
  int nonce;

  @override
  int height;

  @JsonKey(name: 'transaction_count')
  int transactionCount;

  CruzBlockHeader();

  factory CruzBlockHeader.fromJson(Map<String, dynamic> json) =>
      _$CruzBlockHeaderFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CruzBlockHeaderToJson(this);

  CruzBlockId id() => CruzBlockId.compute(jsonEncode(this));

  int deltaWork(BlockHeader x) =>
      (decodeBigInt(chainWork.data) - decodeBigInt(x.chainWork.data)).toInt();

  int hashRate(BlockHeader x) =>
      ((decodeBigInt(chainWork.data) - decodeBigInt(x.chainWork.data)) /
              (BigInt.from(time - x.time)))
          .toInt();
}

@JsonSerializable()
class CruzBlock extends Block {
  @override
  CruzBlockHeader header;

  @override
  List<CruzTransaction> transactions;

  CruzBlock();

  factory CruzBlock.fromJson(Map<String, dynamic> json) =>
      _$CruzBlockFromJson(json);

  Map<String, dynamic> toJson() => _$CruzBlockToJson(this);

  @override
  CruzBlockId id() => header.id();
}

class CruzPeerNetwork extends PeerNetwork {
  @override
  String parseUri(String uriText, String genesisId) {
    if (!Uri.parse(uriText).hasScheme) uriText = 'wss://' + uriText;
    Uri uri = Uri.parse(uriText);
    Uri url = uri.replace(port: uri.hasPort ? uri.port : 8831);
    return url.toString() + '/' + genesisId;
  }

  @override
  Peer addPeerWithSpec(PeerPreference spec, String genesisBlockId) =>
      addPeer(CruzPeer(spec, parseUri(spec.url, genesisBlockId)));
}

class CruzPeer extends PersistentWebSocketClient {
  Map<String, TransactionCallback> addressFilter =
      Map<String, TransactionCallback>();

  @override
  CruzBlockId tipId;

  @override
  CruzBlockHeader tip;

  @override
  num minAmount;

  @override
  num minFee;

  CruzPeer(PeerPreference spec, String address) : super(spec, address);

  @override
  void handleDisconnected() {
    addressFilter = Map<String, TransactionCallback>();
    tipId = null;
    tip = null;
  }

  @override
  void handleConnected() {
    addJsonMessage(
      <String, dynamic>{
        'type': 'get_tip_header',
      },
      (Map<String, dynamic> response) {
        if (response == null) return;
        checkEquals('tip_header', response['type'], spec.debugPrint);
        tipId = CruzBlockId.fromJson(response['body']['block_id']);
        tip = CruzBlockHeader.fromJson(response['body']['header']);
        if (spec.debugPrint != null)
          spec.debugPrint('initial blockHeight=${tip.height}');
        setState(PeerState.ready);
        if (tipChanged != null) tipChanged();
      },
    );

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
  Future<TransactionIteratorResults> getTransactions(PublicAddress address,
      {int startHeight, int startIndex, int endHeight, int limit = 20}) {
    Completer<TransactionIteratorResults> completer =
        Completer<TransactionIteratorResults>();

    if (startHeight == null) {
      if (endHeight == null) {
        // Get transactions in reverse order
        startHeight = tip.height;
        endHeight = 0;
      } else
        startHeight = 0;
    } else if (endHeight == null) endHeight = tip.height;

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
      if (ret.height == startHeight && ret.index == startIndex)
        ret.height = ret.index = 0;

      if (blocks == null)
        completer.complete(ret);
      else {
        for (var block in blocks) {
          List<Transaction> tx = CruzBlock.fromJson(block).transactions;
          for (Transaction x in tx) x.height = block['header']['height'];
          ret.transactions += tx;
        }
        completer.complete(ret);
      }
    });
    return completer.future;
  }

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
        if (spec.debugPrint != null)
          spec.debugPrint('putTransaction error: ' + result['error']);
        completer.complete(null);
      } else {
        completer
            .complete(CruzTransactionId.fromJson(result['transaction_id']));
        handleNewTransaction(transaction);
      }
    });
    return completer.future;
  }

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
        if (error != null && spec.debugPrint != null)
          spec.debugPrint('filterAdd error: $error');
        completer.complete(error == null);
      },
    );
    return completer.future;
  }

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
        if (transactions != null)
          for (var transaction in transactions)
            handleNewTransaction(CruzTransaction.fromJson(transaction));
        completer.complete(true);
      },
    );
    return completer.future;
  }

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
        completer.complete(BlockHeaderMessage(
            CruzBlockId.fromJson(response['body']['block_id']),
            CruzBlockHeader.fromJson(response['body']['header'])));
      },
    );
    return completer.future;
  }

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
        completer.complete(BlockMessage(
            CruzBlockId.fromJson(response['body']['block_id']),
            CruzBlock.fromJson(response['body']['block'])));
      },
    );
    return completer.future;
  }

  @override
  Future<Transaction> getTransaction(TransactionId id) {
    Completer<Transaction> completer = Completer<Transaction>();
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
        CruzTransaction transaction =
            CruzTransaction.fromJson(response['body']['transaction']);
        transaction.height = response['body']['height'];
        completer.complete(transaction);
      },
    );
    return completer.future;
  }

  void handleMessage(String message) {
    if (spec.debugPrint != null)
      debugPrintLong('got message ' + message, spec.debugPrint);
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
        handleProtocol(() => dispatchFromJsonResponseQueue(json));
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

  void handleFilterBlock(CruzBlockId id, CruzBlock block, bool undo) {
    if (undo) {
      if (spec.debugPrint != null)
        spec.debugPrint('got undo!  reorg occurring.');
    } else {
      int expectedHeight = tip.height + 1;
      tipId = id;
      tip = block.header;
      if (spec.debugPrint != null)
        spec.debugPrint('new blockHeight=${tip.height} ' +
            (expectedHeight == tip.height ? 'as expected' : 'reorg'));
      if (tipChanged != null) tipChanged();
    }

    if (block.transactions != null)
      for (CruzTransaction transaction in block.transactions) {
        transaction.height = undo ? -1 : block.header.height;
        handleNewTransaction(transaction);
      }
  }

  void handleNewTransaction(CruzTransaction transaction) {
    TransactionCallback cb = transaction.from != null
        ? addressFilter[transaction.from.toJson()]
        : null;
    cb = cb ?? addressFilter[transaction.to.toJson()];
    if (cb != null) cb(transaction);
  }
}

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
