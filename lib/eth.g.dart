// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EthereumTransaction _$EthereumTransactionFromJson(Map<String, dynamic> json) {
  return EthereumTransaction()
    ..hash = json['hash'] == null
        ? null
        : EthereumTransactionId.fromJson(json['hash'] as String)
    ..index = ETH.hexDecodeInt(json['transactionIndex'] as String)
    ..height = ETH.hexDecodeInt(json['blockNumber'] as String)
    ..nonce = ETH.hexDecodeInt(json['nonce'] as String)
    ..from = json['from'] == null
        ? null
        : EthereumAddressHash.fromJson(json['from'] as String)
    ..to = json['to'] == null
        ? null
        : EthereumAddressHash.fromJson(json['to'] as String)
    ..value = ETH.hexDecodeInt(json['value'] as String)
    ..gas = ETH.hexDecodeInt(json['gas'] as String)
    ..gasPrice = ETH.hexDecodeInt(json['gasPrice'] as String)
    ..input = ETH.hexDecode(json['input'] as String);
}

Map<String, dynamic> _$EthereumTransactionToJson(EthereumTransaction instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('hash', instance.hash);
  writeNotNull('transactionIndex', instance.index);
  writeNotNull('blockNumber', instance.height);
  writeNotNull('nonce', instance.nonce);
  writeNotNull('from', instance.from);
  writeNotNull('to', instance.to);
  writeNotNull('value', instance.value);
  writeNotNull('gas', instance.gas);
  writeNotNull('gasPrice', instance.gasPrice);
  writeNotNull('input', instance.input);
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
    ..hashRoot = json['transactionsRoot'] == null
        ? null
        : EthereumTransactionId.fromJson(json['transactionsRoot'] as String)
    ..time = ETH.hexDecodeInt(json['timestamp'] as String)
    ..difficulty = json['difficulty'] == null
        ? null
        : BigInt.parse(json['difficulty'] as String)
    ..totalDifficulty = json['totalDifficulty'] == null
        ? null
        : BigInt.parse(json['totalDifficulty'] as String)
    ..nonceValue =
        json['nonce'] == null ? null : BigInt.parse(json['nonce'] as String)
    ..height = ETH.hexDecodeInt(json['number'] as String)
    ..miner = json['miner'] == null
        ? null
        : EthereumAddressHash.fromJson(json['miner'] as String)
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
  writeNotNull('transactionsRoot', instance.hashRoot);
  writeNotNull('timestamp', instance.time);
  writeNotNull('difficulty', instance.difficulty?.toString());
  writeNotNull('totalDifficulty', instance.totalDifficulty?.toString());
  writeNotNull('nonce', instance.nonceValue?.toString());
  writeNotNull('number', instance.height);
  writeNotNull('miner', instance.miner);
  writeNotNull('size', instance.size);
  return val;
}
