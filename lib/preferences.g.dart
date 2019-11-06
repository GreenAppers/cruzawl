// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeerPreference _$PeerPreferenceFromJson(Map<String, dynamic> json) {
  return PeerPreference(
    json['name'] as String,
    json['url'] as String,
    json['currency'] as String,
    json['options'] as String,
    root: json['root'] as String,
    type: json['type'] as String,
  )
    ..sshUrl = json['sshUrl'] as String
    ..sshUser = json['sshUser'] as String
    ..sshKey = json['sshKey'] as String
    ..sshPassword = json['sshPassword'] as String
    ..priority = json['priority'] as int;
}

Map<String, dynamic> _$PeerPreferenceToJson(PeerPreference instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('url', instance.url);
  writeNotNull('root', instance.root);
  writeNotNull('currency', instance.currency);
  writeNotNull('options', instance.options);
  writeNotNull('type', instance.type);
  writeNotNull('sshUrl', instance.sshUrl);
  writeNotNull('sshUser', instance.sshUser);
  writeNotNull('sshKey', instance.sshKey);
  writeNotNull('sshPassword', instance.sshPassword);
  writeNotNull('priority', instance.priority);
  return val;
}

Contact _$ContactFromJson(Map<String, dynamic> json) {
  return Contact(
    json['name'] as String,
    json['url'] as String,
    json['icon'] as String,
    json['currency'] as String,
    json['options'] as String,
    json['addressText'] as String,
  );
}

Map<String, dynamic> _$ContactToJson(Contact instance) => <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'icon': instance.icon,
      'currency': instance.currency,
      'options': instance.options,
      'addressText': instance.addressText,
    };
