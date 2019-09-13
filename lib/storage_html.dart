// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

/// https://www.w3.org/TR/webstorage/ [PreferenceStorage]
class PreferenceLocalStorage extends PreferenceStorage {
  @override
  Future<PreferenceLocalStorage> load() async => this;

  @override
  Future<void> setPreference(String key, dynamic value, {bool store = true}) {
    window.localStorage['preference:$key'] = jsonEncode(value);
    return voidResult();
  }

  @override
  dynamic getPreference(String key) {
    String preference = window.localStorage['preference:$key'];
    return preference != null ? jsonDecode(preference) : null;
  }
}
