// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';
import "package:pointycastle/digests/sha256.dart";
import 'package:sembast/sembast.dart';

import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/util.dart';

part 'preferences.g.dart';

class CruzawlPreferences extends SembastPreferences {
  String walletsPassword;
  CruzawlPreferences(Database db) : super(db);

  String get theme => data['theme'] ?? 'teal';
  set theme(String value) => setPreference('theme', value);

  String get localCurrency =>
      data['localCurrency'] ?? NumberFormat.currency().currencyName;
  set localCurrency(String value) => setPreference('localCurrency', value);

  int get minimumReserveAddress => data['minimumReserveAddress'] ?? 5;
  set minimumReserveAddress(int value) =>
      setPreference('minimumReserveAddress', value);

  bool get networkEnabled => data['networkEnabled'] ?? true;
  set networkEnabled(bool value) => setPreference('networkEnabled', value);

  bool get debugLog => data['debugLog'] ?? false;
  set debugLog(bool value) => setPreference('debugLog', value);

  bool get insecureDeviceWarning => data['insecureDeviceWarning'] ?? true;
  set insecureDeviceWarning(bool value) =>
      setPreference('insecureDeviceWarning', value);

  bool get unitTestBeforeCreating => data['unitTestBeforeCreating'] ?? false;
  set unitTestBeforeCreating(bool value) =>
      setPreference('unitTestBeforeCreating', value);

  bool get verifyAddressEveryLoad => data['verifyAddressEveryLoad'] ?? false;
  set verifyAddressEveryLoad(bool value) =>
      setPreference('verifyAddressEveryLoad', value);

  bool get walletNameInTitle => data['walletNameInTitle'] ?? false;
  set walletNameInTitle(bool value) =>
      setPreference('walletNameInTitle', value);

  bool get walletsEncrypted => data['walletsEncrypted'] ?? false;

  Map<String, String> get wallets {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      return Map<String, String>.from(
          SecretBoxDecoder(password).convert(data['wallets']));
    } else {
      return Map<String, String>.from(data['wallets'] ?? Map<String, String>());
    }
  }

  set wallets(Map<String, String> value) {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      setPreference('wallets', SecretBoxEncoder(password).convert(value));
    } else {
      setPreference('wallets', value);
    }
  }

  List<PeerPreference> get peers {
    var peers = data['peers'];
    if (peers == null) {
      return <PeerPreference>[
        PeerPreference('Satoshi Locomoco', 'wallet.cruzbit.xyz', 'CRUZ', '')
      ];
    }
    return peers.map<PeerPreference>((v) => PeerPreference.fromJson(v)).toList()
      ..sort(PeerPreference.comparePriority);
  }

  set peers(List<PeerPreference> value) {
    int priority = 10;
    for (int i = value.length - 1; i >= 0; i--, priority += 10) {
      value[i].priority = priority;
    }
    setPreference('peers', value.map((v) => v.toJson()).toList());
  }

  void encryptWallets(String password) {
    bool enabled = password != null && password.isNotEmpty;
    if (enabled == walletsEncrypted) return;
    Map<String, String> loadedWallets = wallets;
    setPreference('walletsEncrypted', enabled, store: false);
    walletsPassword = password;
    wallets = loadedWallets;
  }
}

@JsonSerializable()
class PeerPreference {
  String name, url, currency, options;
  int priority = 100;

  @JsonKey(ignore: true)
  StringCallback debugPrint;

  @JsonKey(ignore: true)
  int debugLevel = debugLevelInfo;

  PeerPreference(this.name, this.url, this.currency, this.options,
      {this.debugPrint});

  factory PeerPreference.fromJson(Map<String, dynamic> json) =>
      _$PeerPreferenceFromJson(json);

  Map<String, dynamic> toJson() => _$PeerPreferenceToJson(this);

  bool get ignoreBadCert =>
      options != null && options.contains(',ignoreBadCert,');

  static String formatOptions({bool ignoreBadCert = false}) {
    String options = ',';
    if (ignoreBadCert) options += 'ignoreBadCert,';
    return options;
  }

  static int comparePriority(dynamic a, dynamic b) => b.priority - a.priority;
}
