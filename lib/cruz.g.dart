// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cruz.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CruzTransaction _$CruzTransactionFromJson(Map<String, dynamic> json) {
  return CruzTransaction(
    json['from'] == null
        ? null
        : CruzPublicKey.fromJson(json['from'] as String),
    json['to'] == null ? null : CruzPublicKey.fromJson(json['to'] as String),
    json['amount'] as int,
    json['fee'] as int,
    json['memo'] as String,
    matures: json['matures'] as int,
    expires: json['expires'] as int,
    series: json['series'] as int,
  )
    ..time = json['time'] as int
    ..nonce = json['nonce'] as int
    ..signature = json['signature'] == null
        ? null
        : CruzSignature.fromJson(json['signature'] as String);
}

Map<String, dynamic> _$CruzTransactionToJson(CruzTransaction instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('time', instance.time);
  writeNotNull('nonce', instance.nonce);
  writeNotNull('from', instance.from);
  writeNotNull('to', instance.to);
  writeNotNull('amount', instance.amount);
  writeNotNull('fee', instance.fee);
  writeNotNull('memo', instance.memo);
  writeNotNull('matures', instance.matures);
  writeNotNull('expires', instance.expires);
  writeNotNull('series', instance.series);
  writeNotNull('signature', instance.signature);
  return val;
}

CruzAddress _$CruzAddressFromJson(Map<String, dynamic> json) {
  return CruzAddress(
    json['publicKey'] == null
        ? null
        : CruzPublicKey.fromJson(json['publicKey'] as String),
    json['privateKey'] == null
        ? null
        : CruzPrivateKey.fromJson(json['privateKey'] as String),
    json['chainCode'] == null
        ? null
        : CruzChainCode.fromJson(json['chainCode'] as String),
  )
    ..name = json['name'] as String
    ..state = _$enumDecodeNullable(_$AddressStateEnumMap, json['state'])
    ..accountId = json['accountId'] as int
    ..chainIndex = json['chainIndex'] as int
    ..earliestSeen = json['earliestSeen'] as int
    ..latestSeen = json['latestSeen'] as int
    ..balance = json['balance'] as num;
}

Map<String, dynamic> _$CruzAddressToJson(CruzAddress instance) {
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

CruzBlockIds _$CruzBlockIdsFromJson(Map<String, dynamic> json) {
  return CruzBlockIds()
    ..block_ids = (json['block_ids'] as List)
        ?.map((e) => e == null ? null : CruzBlockId.fromJson(e as String))
        ?.toList();
}

Map<String, dynamic> _$CruzBlockIdsToJson(CruzBlockIds instance) =>
    <String, dynamic>{
      'block_ids': instance.block_ids,
    };

CruzBlockHeader _$CruzBlockHeaderFromJson(Map<String, dynamic> json) {
  return CruzBlockHeader()
    ..previous = json['previous'] == null
        ? null
        : CruzBlockId.fromJson(json['previous'] as String)
    ..hashListRoot = json['hash_list_root'] == null
        ? null
        : CruzTransactionId.fromJson(json['hash_list_root'] as String)
    ..time = json['time'] as int
    ..target = json['target'] == null
        ? null
        : CruzBlockId.fromJson(json['target'] as String)
    ..chainWork = json['chain_work'] == null
        ? null
        : CruzBlockId.fromJson(json['chain_work'] as String)
    ..nonce = json['nonce'] as int
    ..height = json['height'] as int
    ..transactionCount = json['transaction_count'] as int;
}

Map<String, dynamic> _$CruzBlockHeaderToJson(CruzBlockHeader instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('previous', instance.previous);
  writeNotNull('hash_list_root', instance.hashListRoot);
  writeNotNull('time', instance.time);
  writeNotNull('target', instance.target);
  writeNotNull('chain_work', instance.chainWork);
  writeNotNull('nonce', instance.nonce);
  writeNotNull('height', instance.height);
  writeNotNull('transaction_count', instance.transactionCount);
  return val;
}

CruzBlock _$CruzBlockFromJson(Map<String, dynamic> json) {
  return CruzBlock()
    ..header = json['header'] == null
        ? null
        : CruzBlockHeader.fromJson(json['header'] as Map<String, dynamic>)
    ..transactions = (json['transactions'] as List)
        ?.map((e) => e == null
            ? null
            : CruzTransaction.fromJson(e as Map<String, dynamic>))
        ?.toList();
}

Map<String, dynamic> _$CruzBlockToJson(CruzBlock instance) => <String, dynamic>{
      'header': instance.header,
      'transactions': instance.transactions,
    };
