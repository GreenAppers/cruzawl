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
  )..priority = json['priority'] as int;
}

Map<String, dynamic> _$PeerPreferenceToJson(PeerPreference instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'currency': instance.currency,
      'options': instance.options,
      'priority': instance.priority,
    };
