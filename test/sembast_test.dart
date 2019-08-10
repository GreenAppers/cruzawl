// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';

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
}
