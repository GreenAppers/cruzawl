// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/util.dart';

void main() {
  test('SecretBoxCodec', () {
    SecretBoxCodec codec = SecretBoxCodec(randBytes(32));
    PeerPreference peer = PeerPreference('foo', 'bar', 'baz', 'bat');
    Map<String, dynamic> peerJson = peer.toJson();
    String peerText = jsonEncode(peerJson);
    String cipherText = codec.encoder.convert(peerJson);
    Map<String, dynamic> plainJson = codec.decoder.convert(cipherText);
    String plainText = jsonEncode(plainJson);
    expect(plainText, peerText);
  });

  test('CruzawlPreferences', () async {
    CruzawlPreferences preferences = CruzawlPreferences(
        SembastPreferences(
            await databaseFactoryMemoryFs.openDatabase('preferences.db')),
        () => 'USD');
    await preferences.storage.load();

    String password = 'foobar';
    Map<String, String> wallets = {'My Wallet': 'fake wallet data'};
    List<PeerPreference> peers = [
      PeerPreference('Peer', '127.0.0.1', 'CRUZ', '')
    ];
    Map<String, Contact> contacts = {
      'Contact': Contact('Contact', null, null, 'CRUZ', '', 'address')
    };

    await preferences.setTheme('green');
    await preferences.setLocalCurrency('EUR');
    await preferences.setNetworkEnabled(false);
    await preferences.setMinimumReserveAddress(3);
    await preferences.setNetworkEnabled(false);
    await preferences.setDebugLog(true);
    await preferences.setInsecureDeviceWarning(false);
    await preferences.setUnitTestBeforeCreating(true);
    await preferences.setVerifyAddressEveryLoad(true);
    await preferences.setWalletNameInTitle(true);
    await preferences.setWallets(wallets);
    await preferences.setPeers(peers);
    await preferences.setContacts(contacts);

    preferences = CruzawlPreferences(
        SembastPreferences(
            await databaseFactoryMemoryFs.openDatabase('preferences.db')),
        () => 'USD');
    await preferences.storage.load();
    expect(preferences.theme, 'green');
    expect(preferences.localCurrency, 'EUR');
    expect(preferences.networkEnabled, false);
    expect(preferences.minimumReserveAddress, 3);
    expect(preferences.networkEnabled, false);
    expect(preferences.debugLog, true);
    expect(preferences.insecureDeviceWarning, false);
    expect(preferences.unitTestBeforeCreating, true);
    expect(preferences.verifyAddressEveryLoad, true);
    expect(preferences.walletNameInTitle, true);
    expect(preferences.wallets.keys.first, wallets.keys.first);
    expect(preferences.wallets.values.first, wallets.values.first);
    expect(preferences.peers.first.name, peers.first.name);
    expect(preferences.contacts.keys.first, contacts.values.first.addressText);
    expect(preferences.contacts.values.first.name, contacts.values.first.name);
    await preferences.encryptWallets(password);

    preferences = CruzawlPreferences(
        SembastPreferences(
            await databaseFactoryMemoryFs.openDatabase('preferences.db')),
        () => 'USD');
    await preferences.storage.load();
    preferences.walletsPassword = password;
    expect(preferences.wallets.keys.first, wallets.keys.first);
    expect(preferences.wallets.values.first, wallets.values.first);
  });
}
