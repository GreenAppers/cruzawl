// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'btc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BitcoinTransactionOutput _$BitcoinTransactionOutputFromJson(
    Map<String, dynamic> json) {
  return BitcoinTransactionOutput()
    ..value = json['value'] as int
    ..address = json['addr'] == null
        ? null
        : BitcoinAddressHash.fromJson(json['addr'] as String)
    ..script = json['script'] == null
        ? null
        : BitcoinScript.fromJson(json['script'] as String);
}

Map<String, dynamic> _$BitcoinTransactionOutputToJson(
    BitcoinTransactionOutput instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('value', instance.value);
  writeNotNull('addr', instance.address);
  writeNotNull('script', instance.script);
  return val;
}

BitcoinTransaction _$BitcoinTransactionFromJson(Map<String, dynamic> json) {
  return BitcoinTransaction()
    ..hash = json['hash'] == null
        ? null
        : BitcoinTransactionId.fromJson(json['hash'] as String)
    ..version = json['ver'] as int
    ..size = json['size'] as int
    ..time = json['time'] as int
    ..lockTime = json['lock_time'] as int
    ..txIndex = json['tx_index'] as int
    ..height = json['block_height'] as int
    ..inputs = (json['inputs'] as List)
        ?.map((e) => e == null
            ? null
            : BitcoinTransactionInput.fromJson(e as Map<String, dynamic>))
        ?.toList()
    ..outputs = (json['out'] as List)
        ?.map((e) => e == null
            ? null
            : BitcoinTransactionOutput.fromJson(e as Map<String, dynamic>))
        ?.toList();
}

Map<String, dynamic> _$BitcoinTransactionToJson(BitcoinTransaction instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('hash', instance.hash);
  writeNotNull('ver', instance.version);
  writeNotNull('size', instance.size);
  writeNotNull('time', instance.time);
  writeNotNull('lock_time', instance.lockTime);
  writeNotNull('tx_index', instance.txIndex);
  writeNotNull('block_height', instance.height);
  writeNotNull('inputs', instance.inputs);
  writeNotNull('out', instance.outputs);
  return val;
}

BitcoinAddress _$BitcoinAddressFromJson(Map<String, dynamic> json) {
  return BitcoinAddress(
    json['publicKey'] == null
        ? null
        : BitcoinPublicKey.fromJson(json['publicKey'] as String),
    json['privateKey'] == null
        ? null
        : BitcoinPrivateKey.fromJson(json['privateKey'] as String),
    json['chainCode'] == null
        ? null
        : BitcoinChainCode.fromJson(json['chainCode'] as String),
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
    ..identifier = json['identifier'] == null
        ? null
        : BitcoinAddressIdentifier.fromJson(json['identifier'] as String)
    ..publicAddress = json['publicAddress'] == null
        ? null
        : BitcoinAddressHash.fromJson(json['publicAddress'] as String);
}

Map<String, dynamic> _$BitcoinAddressToJson(BitcoinAddress instance) {
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
  writeNotNull('identifier', instance.identifier);
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

BitcoinBlockIds _$BitcoinBlockIdsFromJson(Map<String, dynamic> json) {
  return BitcoinBlockIds()
    ..block_ids = (json['block_ids'] as List)
        ?.map((e) => e == null ? null : BitcoinBlockId.fromJson(e as String))
        ?.toList();
}

Map<String, dynamic> _$BitcoinBlockIdsToJson(BitcoinBlockIds instance) =>
    <String, dynamic>{
      'block_ids': instance.block_ids,
    };

BitcoinBlockHeader _$BitcoinBlockHeaderFromJson(Map<String, dynamic> json) {
  return BitcoinBlockHeader()
    ..hash = json['hash'] == null
        ? null
        : BitcoinBlockId.fromJson(json['hash'] as String)
    ..previous = json['prev_block'] == null
        ? null
        : BitcoinBlockId.fromJson(json['prev_block'] as String)
    ..hashRoot = json['mrkl_root'] == null
        ? null
        : BitcoinTransactionId.fromJson(json['mrkl_root'] as String)
    ..time = json['time'] as int
    ..bits = json['bits'] as int
    ..nonce = json['nonce'] as int
    ..height = json['height'] as int
    ..version = json['ver'] as int
    ..transactionCount = json['n_tx'] as int
    ..blockIndex = json['block_index'] as int
    ..prevBlockIndex = json['prevBlockIndex'] as int;
}

Map<String, dynamic> _$BitcoinBlockHeaderToJson(BitcoinBlockHeader instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('hash', instance.hash);
  writeNotNull('prev_block', instance.previous);
  writeNotNull('mrkl_root', instance.hashRoot);
  writeNotNull('time', instance.time);
  writeNotNull('bits', instance.bits);
  writeNotNull('nonce', instance.nonce);
  writeNotNull('height', instance.height);
  writeNotNull('ver', instance.version);
  writeNotNull('n_tx', instance.transactionCount);
  writeNotNull('block_index', instance.blockIndex);
  writeNotNull('prevBlockIndex', instance.prevBlockIndex);
  return val;
}
