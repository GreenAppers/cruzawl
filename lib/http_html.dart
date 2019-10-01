// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:cruzawl/http.dart';

/// dart:html [HttpClient] implementation.
class HttpClientImpl extends HttpClient {
  static const String type = 'html';

  @override
  Future<HttpResponse> request(String url, {String method, String data}) {
    Completer<HttpResponse> completer = Completer<HttpResponse>();
    html.HttpRequest.request(url, method: method).then(
        (r) => completer.complete(HttpResponse(r.status, r.responseText)));
    return completer.future;
  }
}
