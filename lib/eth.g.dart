// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EthereumTransaction _$EthereumTransactionFromJson(Map<String, dynamic> json) {
  return EthereumTransaction(
    json['from'] == null
        ? null
        : EthereumAddressHash.fromJson(json['from'] as String),
    json['to'] == null
        ? null
        : EthereumAddressHash.fromJson(json['to'] as String),
    ETH.hexDecodeInt(json['value'] as String),
    ETH.hexDecodeInt(json['gas'] as String),
    ETH.hexDecodeInt(json['gasPrice'] as String),
    ETH.hexDecodeInt(json['nonce'] as String),
    input: ETH.hexDecode(json['input'] as String),
    sigR: ETH.hexDecode(json['r'] as String),
    sigS: ETH.hexDecode(json['s'] as String),
    sigV: ETH.hexDecodeInt(json['v'] as String),
  )
    ..hash = json['hash'] == null
        ? null
        : EthereumTransactionId.fromJson(json['hash'] as String)
    ..index = ETH.hexDecodeInt(json['transactionIndex'] as String)
    ..height = ETH.hexDecodeInt(json['blockNumber'] as String);
}

Map<String, dynamic> _$EthereumTransactionToJson(EthereumTransaction instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('hash', instance.hash);
  writeNotNull('transactionIndex', ETH.hexEncodeInt(instance.index));
  writeNotNull('blockNumber', ETH.hexEncodeInt(instance.height));
  writeNotNull('nonce', ETH.hexEncodeInt(instance.nonce));
  writeNotNull('from', instance.from);
  writeNotNull('to', instance.to);
  writeNotNull('value', ETH.hexEncodeInt(instance.value));
  writeNotNull('gas', ETH.hexEncodeInt(instance.gas));
  writeNotNull('gasPrice', ETH.hexEncodeInt(instance.gasPrice));
  writeNotNull('input', ETH.hexEncode(instance.input));
  writeNotNull('v', ETH.hexEncodeInt(instance.sigV));
  writeNotNull('r', ETH.hexEncode(instance.sigR));
  writeNotNull('s', ETH.hexEncode(instance.sigS));
  return val;
}

EthereumAddress _$EthereumAddressFromJson(Map<String, dynamic> json) {
  return EthereumAddress(
    json['publicKey'] == null
        ? null
        : EthereumPublicKey.fromJson(json['publicKey'] as String),
    json['privateKey'] == null
        ? null
        : EthereumPrivateKey.fromJson(json['privateKey'] as String),
    json['chainCode'] == null
        ? null
        : EthereumChainCode.fromJson(json['chainCode'] as String),
    json['chainIndex'] as int,
    json['chainDepth'] as int,
    json['parentFingerprint'] as int,
  )
    ..name = json['name'] as String
    ..state = _$enumDecodeNullable(_$AddressStateEnumMap, json['state'])
    ..accountId = json['accountId'] as int
    ..earliestSeen = json['earliestSeen'] as int
    ..latestSeen = json['latestSeen'] as int
    ..balance = json['balance'] as num
    ..publicAddress = json['publicAddress'] == null
        ? null
        : EthereumAddressHash.fromJson(json['publicAddress'] as String);
}

Map<String, dynamic> _$EthereumAddressToJson(EthereumAddress instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('state', _$AddressStateEnumMap[instance.state]);
  writeNotNull('accountId', instance.accountId);
  writeNotNull('chainIndex', instance.chainIndex);
  writeNotNull('earliestSeen', instance.earliestSeen);
  writeNotNull('latestSeen', instance.latestSeen);
  writeNotNull('balance', instance.balance);
  writeNotNull('chainDepth', instance.chainDepth);
  writeNotNull('parentFingerprint', instance.parentFingerprint);
  writeNotNull('publicAddress', instance.publicAddress);
  writeNotNull('publicKey', instance.publicKey);
  writeNotNull('privateKey', instance.privateKey);
  writeNotNull('chainCode', instance.chainCode);
  return val;
}

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$AddressStateEnumMap = {
  AddressState.reserve: 'reserve',
  AddressState.open: 'open',
  AddressState.used: 'used',
  AddressState.remove: 'remove',
};

EthereumBlockIds _$EthereumBlockIdsFromJson(Map<String, dynamic> json) {
  return EthereumBlockIds()
    ..block_ids = (json['block_ids'] as List)
        ?.map((e) => e == null ? null : EthereumBlockId.fromJson(e as String))
        ?.toList();
}

Map<String, dynamic> _$EthereumBlockIdsToJson(EthereumBlockIds instance) =>
    <String, dynamic>{
      'block_ids': instance.block_ids,
    };

EthereumBlockHeader _$EthereumBlockHeaderFromJson(Map<String, dynamic> json) {
  return EthereumBlockHeader()
    ..hash = json['hash'] == null
        ? null
        : EthereumBlockId.fromJson(json['hash'] as String)
    ..previous = json['parentHash'] == null
        ? null
        : EthereumBlockId.fromJson(json['parentHash'] as String)
    ..unclesRoot = json['sha3Uncles'] == null
        ? null
        : EthereumBlockId.fromJson(json['sha3Uncles'] as String)
    ..miner = json['miner'] == null
        ? null
        : EthereumAddressHash.fromJson(json['miner'] as String)
    ..stateRoot = json['stateRoot'] == null
        ? null
        : EthereumTransactionId.fromJson(json['stateRoot'] as String)
    ..hashRoot = json['transactionsRoot'] == null
        ? null
        : EthereumTransactionId.fromJson(json['transactionsRoot'] as String)
    ..receiptsRoot = json['receiptsRoot'] == null
        ? null
        : EthereumTransactionId.fromJson(json['receiptsRoot'] as String)
    ..logsBloom = ETH.hexDecode(json['logsBloom'] as String)
    ..difficulty = json['difficulty'] == null
        ? null
        : BigInt.parse(json['difficulty'] as String)
    ..totalDifficulty = json['totalDifficulty'] == null
        ? null
        : BigInt.parse(json['totalDifficulty'] as String)
    ..height = ETH.hexDecodeInt(json['number'] as String)
    ..gasLimit = ETH.hexDecodeInt(json['gasLimit'] as String)
    ..gasUsed = ETH.hexDecodeInt(json['gasUsed'] as String)
    ..time = ETH.hexDecodeInt(json['timestamp'] as String)
    ..extraData = ETH.hexDecode(json['extraData'] as String)
    ..mixHash = ETH.hexDecode(json['mixHash'] as String)
    ..nonce = ETH.hexDecode(json['nonce'] as String)
    ..size = ETH.hexDecodeInt(json['size'] as String);
}

Map<String, dynamic> _$EthereumBlockHeaderToJson(EthereumBlockHeader instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('hash', instance.hash);
  writeNotNull('parentHash', instance.previous);
  writeNotNull('sha3Uncles', instance.unclesRoot);
  writeNotNull('miner', instance.miner);
  writeNotNull('stateRoot', instance.stateRoot);
  writeNotNull('transactionsRoot', instance.hashRoot);
  writeNotNull('receiptsRoot', instance.receiptsRoot);
  writeNotNull('logsBloom', ETH.hexEncode(instance.logsBloom));
  writeNotNull('difficulty', ETH.hexEncodeBigInt(instance.difficulty));
  writeNotNull(
      'totalDifficulty', ETH.hexEncodeBigInt(instance.totalDifficulty));
  writeNotNull('number', ETH.hexEncodeInt(instance.height));
  writeNotNull('gasLimit', ETH.hexEncodeInt(instance.gasLimit));
  writeNotNull('gasUsed', ETH.hexEncodeInt(instance.gasUsed));
  writeNotNull('timestamp', ETH.hexEncodeInt(instance.time));
  writeNotNull('extraData', ETH.hexEncode(instance.extraData));
  writeNotNull('mixHash', ETH.hexEncode(instance.mixHash));
  writeNotNull('nonce', ETH.hexEncode(instance.nonce));
  writeNotNull('size', ETH.hexEncodeInt(instance.size));
  return val;
}
