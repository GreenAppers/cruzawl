// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:cruzawl/http.dart';

/// dart:html [HttpClient] implementation.
class HttpClientImpl extends HttpClient {
  static const String type = 'html';
  HttpClientImpl({StringCallback debugPrint, StringFilter userAgent})
      : super(debugPrint) {}

  @override
  Future<HttpResponse> request(String url, {String method, String data}) {
    numOutstanding++;
    Completer<HttpResponse> completer = Completer<HttpResponse>();
    html.HttpRequest.request(url, method: method).then((r) {
      numOutstanding--;
      completer.complete(HttpResponse(r.status, r.responseText));
    });
    return completer.future;
  }
}
