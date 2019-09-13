// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:sembast/sembast.dart';
import 'package:tweetnacl/tweetnacl.dart';

import 'package:cruzawl/util.dart';
import 'package:cruzawl/preferences.dart';

/// Not [SharedPreferences] but [SembastPreferences].
class SembastPreferences extends PreferenceStorage {
  /// sembast: Simple Embedded Application Store database.
  Database db;

  /// Holds single 'preferences' record with the preferences [data].
  var store;

  /// The preferences data. e.g. data.update('theme', 'teal')
  Map<String, dynamic> data = Map<String, dynamic>();

  /// Initialize this preference store with sembast [Database].
  SembastPreferences(this.db) : store = StoreRef<String, dynamic>.main();

  /// Writes the preferences [data] to [store]
  Future<void> save() async => await store.record('preferences').put(db, data);

  /// Reads the preferences from [store] into [data]
  @override
  Future<SembastPreferences> load() async {
    data = Map<String, dynamic>.from(
        await store.record('preferences').get(db) ?? Map<String, dynamic>());
    return this;
  }

  @override
  Future<void> setPreference(String key, dynamic value, {bool store = true}) {
    data[key] = value;
    return store ? save() : voidResult();
  }

  @override
  dynamic getPreference(String key) => data[key];
}

/// Secretbox uses XSalsa20 and Poly1305 to encrypt and authenticate messages with
/// secret-key cryptography. The length of messages is not hidden.
class SecretBoxEncoder extends Converter<Map<String, dynamic>, String> {
  Uint8List password;
  SecretBoxEncoder(this.password) {
    assert(password.length == 32);
  }

  @override
  String convert(Map<String, dynamic> input) {
    /// Nonces are long enough that randomly generated nonces have negligible risk of collision.
    /// Reference: https://godoc.org/golang.org/x/crypto/nacl/secretbox
    Uint8List initialValue = randBytes(8);
    String encoded = base64.encode(initialValue);
    assert(encoded.length == 12);

    final Uint8List message = utf8.encode(jsonEncode(input));
    final SecretBox secretBox = SecretBox(password);
    encoded += base64.encode(secretBox.box_nonce_len(
        message, 0, message.length, _generateNonce(initialValue)));
    return encoded;
  }
}

/// Authenticates and decrypts the given secret box using the key and the nonce.
/// Implements xsalsa20-poly1305.
class SecretBoxDecoder extends Converter<String, Map<String, dynamic>> {
  Uint8List password;
  SecretBoxDecoder(this.password) {
    assert(password.length == 32);
  }

  @override
  Map<String, dynamic> convert(String input) {
    assert(input.length >= 12);
    Uint8List initialValue = base64.decode(input.substring(0, 12));
    input = input.substring(12);

    final Uint8List message = base64.decode(input);
    final SecretBox secretBox = SecretBox(password);
    var decoded = json.decode(utf8.decode(secretBox.open_nonce_len(
        message, 0, message.length, _generateNonce(initialValue))));
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

/// Reference: https://github.com/tekartik/sembast.dart/issues/35#issuecomment-498005269
class SecretBoxCodec extends Codec<Map<String, dynamic>, String> {
  SecretBoxEncoder _encoder;
  SecretBoxDecoder _decoder;

  SecretBoxCodec(Uint8List password) {
    _encoder = SecretBoxEncoder(password);
    _decoder = SecretBoxDecoder(password);
  }

  @override
  Converter<String, Map<String, dynamic>> get decoder => _decoder;

  @override
  Converter<Map<String, dynamic>, String> get encoder => _encoder;
}

// Oops. This should've been 'SecretBox'. Too late now.
const _encryptCodecSignature = 'salsa20';

/// Returns a SecretBox [SembastCodec] using [password].
SembastCodec getSecretBoxSembastCodec(Uint8List password) => SembastCodec(
    signature: _encryptCodecSignature, codec: SecretBoxCodec(password));

/// From https://github.com/jspschool/tweetnacl-dart/blob/master/lib/src/tweetnacl_base.dart#L67
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
