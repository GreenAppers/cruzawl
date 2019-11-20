// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

export 'package:dartssh/http.dart';
import 'package:dartssh/http.dart';

import 'package:cruzawl/util.dart';

/// [Peer] mixin handling HTTP responses.
mixin HttpClientMixin {
  /// HTTP client.
  HttpClient httpClient;

  /// e.g. https://blockchain.info
  Uri httpAddress;

  /// Number of outstanding requests for throttling.
  int get numOutstanding => httpClient.numOutstanding;

  VoidCallback responseComplete;

  void completeResponse<X>(Completer<X> completer, X result) {
    completer.complete(result);
    if (responseComplete != null) responseComplete();
  }
}
