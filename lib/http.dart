// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart';

export 'package:cruzawl/http_html.dart'
    if (dart.library.io) 'package:cruzawl/http_io.dart';
import 'package:cruzawl/util.dart';

/// HTTP response itegrating [io.HttpClient] and [html.HttpRequest].
class HttpResponse {
  int status;
  String text;
  HttpResponse(this.status, [this.text]);
}

/// HTTP client itegrating [io.HttpClient] and [html.HttpRequest].
abstract class HttpClient {
  int numOutstanding = 0;
  StringCallback debugPrint;
  HttpClient([this.debugPrint]);

  Future<HttpResponse> request(String url, {String method, String data});

  void requestWithIncrementalHandler(String url,
      {String method, String data}) async {
    var request = Request(method ?? 'GET', Uri.parse(url));
    var response = await request.send();
    var lineStream =
        response.stream.transform(Utf8Decoder()).transform(LineSplitter());

    /// https://github.com/llamadonica/dart-json-stream-parser/tree/master/test
    await for (String line in lineStream) {
      print(line);
    }
  }
}

/// Asynchronous HTTP request
class HttpRequest {
  String url, method, data;
  Completer<HttpResponse> completer = Completer<HttpResponse>();
  HttpRequest(this.url, this.method, this.data);
}

/// Shim [HttpClient] for testing
class TestHttpClient extends HttpClient {
  Queue<HttpRequest> requests = Queue<HttpRequest>();

  @override
  Future<HttpResponse> request(String url, {String method, String data}) {
    HttpRequest httpRequest = HttpRequest(url, method, data);
    requests.add(httpRequest);
    return httpRequest.completer.future;
  }
}
