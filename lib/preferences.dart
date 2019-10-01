// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';
import "package:pointycastle/digests/sha256.dart";

import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/util.dart';

part 'preferences.g.dart';

/// Interface for preference storage
abstract class PreferenceStorage {
  /// Loads the preferences and returns [this].
  Future<PreferenceStorage> load();

  /// Update a preference and [save()] when (by default) [store] is set.
  Future<void> setPreference(String key, dynamic value, {bool store = true});

  /// Retrieve cached preference for [key]
  dynamic getPreference(String key);
}

class CruzawlPreferences {
  PreferenceStorage storage;
  StringFunction defaultLocalCurrency;
  String walletsPassword;
  CruzawlPreferences(this.storage, this.defaultLocalCurrency);

  String get theme => storage.getPreference('theme') ?? 'blue';
  Future<void> setTheme(String value) => storage.setPreference('theme', value);

  String get localCurrency =>
      storage.getPreference('localCurrency') ?? defaultLocalCurrency();
  Future<void> setLocalCurrency(String value) =>
      storage.setPreference('localCurrency', value);

  int get minimumReserveAddress =>
      storage.getPreference('minimumReserveAddress') ?? 5;
  Future<void> setMinimumReserveAddress(int value) =>
      storage.setPreference('minimumReserveAddress', value);

  bool get networkEnabled => storage.getPreference('networkEnabled') ?? true;
  Future<void> setNetworkEnabled(bool value) =>
      storage.setPreference('networkEnabled', value);

  bool get debugLog => storage.getPreference('debugLog') ?? false;
  Future<void> setDebugLog(bool value) =>
      storage.setPreference('debugLog', value);

  bool get insecureDeviceWarning =>
      storage.getPreference('insecureDeviceWarning') ?? true;
  Future<void> setInsecureDeviceWarning(bool value) =>
      storage.setPreference('insecureDeviceWarning', value);

  bool get unitTestBeforeCreating =>
      storage.getPreference('unitTestBeforeCreating') ?? false;
  Future<void> setUnitTestBeforeCreating(bool value) =>
      storage.setPreference('unitTestBeforeCreating', value);

  bool get verifyAddressEveryLoad =>
      storage.getPreference('verifyAddressEveryLoad') ?? false;
  Future<void> setVerifyAddressEveryLoad(bool value) =>
      storage.setPreference('verifyAddressEveryLoad', value);

  bool get walletNameInTitle =>
      storage.getPreference('walletNameInTitle') ?? false;
  Future<void> setWalletNameInTitle(bool value) =>
      storage.setPreference('walletNameInTitle', value);

  bool get walletsEncrypted =>
      storage.getPreference('walletsEncrypted') ?? false;

  Map<String, String> get wallets {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      return Map<String, String>.from(
          SecretBoxDecoder(password).convert(storage.getPreference('wallets')));
    } else {
      return Map<String, String>.from(
          storage.getPreference('wallets') ?? Map<String, String>());
    }
  }

  Future<void> setWallets(Map<String, String> value) {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      return storage.setPreference(
          'wallets', SecretBoxEncoder(password).convert(value));
    } else {
      return storage.setPreference('wallets', value);
    }
  }

  List<PeerPreference> get peers {
    var peers = storage.getPreference('peers');
    if (peers == null) {
      return <PeerPreference>[
        PeerPreference('Satoshi Locomoco', 'wallet.cruzbit.xyz', 'CRUZ', ''),
        PeerPreference('BLOCKCHAIN', 'ws.blockchain.info', 'BTC', '',
            root: 'https://blockchain.info'),
        //PeerPreference('INFURA', 'mainnet.infura.io', 'ETH', ''),
      ];
    }
    return peers.map<PeerPreference>((v) => PeerPreference.fromJson(v)).toList()
      ..sort(PeerPreference.comparePriority);
  }

  Future<void> setPeers(List<PeerPreference> value) {
    int priority = 10;
    for (int i = value.length - 1; i >= 0; i--, priority += 10) {
      value[i].priority = priority;
    }
    return storage.setPreference(
        'peers', value.map((v) => v.toJson()).toList());
  }

  Map<String, Contact> get contacts {
    Map<String, Contact> ret = {};
    var contacts = storage.getPreference('contacts');
    if (contacts == null) return ret;
    for (Contact contact in contacts.map<Contact>((v) => Contact.fromJson(v))) {
      ret[contact.addressText] = contact;
    }
    return ret;
  }

  Future<void> setContacts(Map<String, Contact> value) => storage.setPreference(
      'contacts', value.values.map((v) => v.toJson()).toList());

  Future<void> encryptWallets(String password) {
    bool enabled = password != null && password.isNotEmpty;
    if (enabled == walletsEncrypted) return voidResult();
    Map<String, String> loadedWallets = wallets;
    storage.setPreference('walletsEncrypted', enabled, store: false);
    walletsPassword = password;
    return setWallets(loadedWallets);
  }
}

@JsonSerializable(includeIfNull: false)
class PeerPreference {
  String name, url, root, currency, options;
  int priority = 100;

  @JsonKey(ignore: true)
  StringCallback debugPrint;

  @JsonKey(ignore: true)
  int debugLevel = debugLevelInfo;

  PeerPreference(this.name, this.url, this.currency, this.options,
      {this.root, this.debugPrint});

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

@JsonSerializable()
class Contact {
  String name, url, icon, currency, options, addressText;

  Contact(this.name, this.url, this.icon, this.currency, this.options,
      this.addressText);

  factory Contact.fromJson(Map<String, dynamic> json) =>
      _$ContactFromJson(json);

  Map<String, dynamic> toJson() => _$ContactToJson(this);
}
