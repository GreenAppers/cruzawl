// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'http.dart';

/// dart:io [HttpClient] implementation.
class HttpClientImpl extends HttpClient {
  static const String type = 'io';

  @override
  Future<HttpResponse> request(String url, {String method, String data}) async {
    Uri uri = Uri.parse(url);
    var request;
    switch (method) {
      case 'POST':
        request = await io.HttpClient().postUrl(uri);
        break;

      default:
        request = await io.HttpClient().getUrl(uri);
        break;
    }

    var response = await request.close();
    HttpResponse ret = HttpResponse(response.statusCode);
    await for (var contents in response.transform(Utf8Decoder())) {
      if (ret.text == null) {
        ret.text = contents;
      } else {
        ret.text += contents;
      }
    }

    return ret;
  }
}
