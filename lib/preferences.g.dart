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
