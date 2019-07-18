// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import "package:pointycastle/digests/sha256.dart";
import 'package:sembast/sembast.dart';

import 'package:cruzawl/network.dart';
import 'package:cruzawl/sembast.dart';

class CruzawlPreferences extends SembastPreferences {
  String walletsPassword;
  CruzawlPreferences(Database db) : super(db);

  String get theme => data['theme'] ?? 'deepOrange';
  set theme(String value) => setPreference('theme', value);

  bool get networkEnabled => data['networkEnabled'] ?? true;
  set networkEnabled(bool value) => setPreference('networkEnabled', value);

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
          Salsa20Decoder(password).convert(data['wallets']));
    } else {
      return Map<String, String>.from(data['wallets'] ?? Map<String, String>());
    }
  }

  set wallets(Map<String, String> value) {
    if (walletsEncrypted) {
      assert(walletsPassword != null);
      Uint8List password = SHA256Digest().process(utf8.encode(walletsPassword));
      setPreference('wallets', Salsa20Encoder(password).convert(value));
    } else {
      setPreference('wallets', value);
    }
  }

  List<PeerPreference> get peers {
    var peers = data['peers'];
    if (peers == null)
      return <PeerPreference>[
        PeerPreference('SatoshiLocomo', 'wallet.cruzbit.xyz', 'CRUZ', '')
      ];
    return peers.map<PeerPreference>((v) => PeerPreference.fromJson(v)).toList()
      ..sort(PeerPreference.comparePriority);
  }

  set peers(List<PeerPreference> value) {
    int priority = 10;
    for (int i = value.length - 1; i >= 0; i--, priority += 10)
      value[i].priority = priority;
    setPreference('peers', value.map((v) => v.toJson()).toList());
  }

  void encryptWallets(String password) {
    bool enabled = password != null && password.length > 0;
    if (enabled == walletsEncrypted) return;
    Map<String, String> loadedWallets = wallets;
    setPreference('walletsEncrypted', enabled, store: false);
    walletsPassword = password;
    wallets = loadedWallets;
  }
}