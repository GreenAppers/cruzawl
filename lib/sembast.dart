// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:sembast/sembast.dart';
import 'package:tweetnacl/tweetnacl.dart';

import 'package:cruzawl/util.dart';

/// Not [SharedPreferences] but [SembastPreferences] !
class SembastPreferences {
  Database db;
  var store;
  bool loaded = false, dirty = false;
  Map<String, dynamic> data = Map<String, dynamic>();
  SembastPreferences(this.db) : store = StoreRef<String, dynamic>.main();

  Future<void> save() async => await store.record('preferences').put(db, data);

  Future<SembastPreferences> load() async {
    data = Map<String, dynamic>.from(
        await store.record('preferences').get(db) ?? Map<String, dynamic>());
    if (dirty) save();
    loaded = true;
    return this;
  }

  Future<void> setPreference(String key, dynamic value, {bool store = true}) {
    data[key] = value;
    if (!loaded || !store) {
      dirty = true;
      return voidResult();
    } else {
      return save();
    }
  }
}

/// https://github.com/tekartik/sembast.dart/issues/35#issuecomment-498005269
class Salsa20Encoder extends Converter<Map<String, dynamic>, String> {
  Uint8List password;
  Salsa20Encoder(this.password) {
    assert(password.length == 32);
  }

  @override
  String convert(Map<String, dynamic> input) {
    Uint8List initialValue = randBytes(8);
    String encoded = base64.encode(initialValue);
    assert(encoded.length == 12);

    final Uint8List message = utf8.encode(jsonEncode(input));
    final SecretBox salsa20 = SecretBox(password);
    encoded += base64.encode(salsa20.box_nonce_len(
        message, 0, message.length, _generateNonce(initialValue)));
    return encoded;
  }
}

class Salsa20Decoder extends Converter<String, Map<String, dynamic>> {
  Uint8List password;
  Salsa20Decoder(this.password) {
    assert(password.length == 32);
  }

  @override
  Map<String, dynamic> convert(String input) {
    assert(input.length >= 12);
    Uint8List initialValue = base64.decode(input.substring(0, 12));
    input = input.substring(12);

    final Uint8List message = base64.decode(input);
    final SecretBox salsa20 = SecretBox(password);
    var decoded = json.decode(utf8.decode(salsa20.open_nonce_len(
        message, 0, message.length, _generateNonce(initialValue))));
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

class Salsa20Codec extends Codec<Map<String, dynamic>, String> {
  Salsa20Encoder _encoder;
  Salsa20Decoder _decoder;

  Salsa20Codec(Uint8List password) {
    _encoder = Salsa20Encoder(password);
    _decoder = Salsa20Decoder(password);
  }

  @override
  Converter<String, Map<String, dynamic>> get decoder => _decoder;

  @override
  Converter<Map<String, dynamic>, String> get encoder => _encoder;
}

Uint8List _generateNonce(Uint8List input) {
  assert(input.length == 8);
  const int nonceLength = 24;
  Int64 nonce = Int64.fromBytes(input);
  Uint8List n = Uint8List(nonceLength);
  for (int i = 0; i < nonceLength; i += 8) {
    n[i + 0] = nonce.shiftRightUnsigned(0).toInt();
    n[i + 1] = nonce.shiftRightUnsigned(8).toInt();
    n[i + 2] = nonce.shiftRightUnsigned(16).toInt();
    n[i + 3] = nonce.shiftRightUnsigned(24).toInt();
    n[i + 4] = nonce.shiftRightUnsigned(32).toInt();
    n[i + 5] = nonce.shiftRightUnsigned(40).toInt();
    n[i + 6] = nonce.shiftRightUnsigned(48).toInt();
    n[i + 7] = nonce.shiftRightUnsigned(56).toInt();
  }
  return n;
}

const _encryptCodecSignature = 'salsa20';

SembastCodec getSalsa20SembastCodec(Uint8List password) => SembastCodec(
    signature: _encryptCodecSignature, codec: Salsa20Codec(password));
