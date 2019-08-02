import 'dart:convert';

import 'package:test/test.dart';

import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/util.dart';

void main() {
  test('Salsa20Codec', () {
    Salsa20Codec codec = Salsa20Codec(randBytes(32));
    PeerPreference peer = PeerPreference('foo', 'bar', 'baz', 'bat');
    Map<String, dynamic> peerJson = peer.toJson();
    String peerText = jsonEncode(peerJson);
    String cipherText = codec.encoder.convert(peerJson);
    Map<String, dynamic> plainJson = codec.decoder.convert(cipherText);
    String plainText = jsonEncode(plainJson);
    expect(plainText, peerText);
  });
}
