// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'http.dart';

class HttpRequest {
  static const String type = 'io';

  static Future<HttpResponse> request(String url,
      {String method, String data}) {
    Uri uri = Uri.parse(url);
    var request;
    switch (method) {
      case 'POST':
        request = await HttpClient().postUrl(uri);
      default:
        request = await HttpClient().getUrl(uri);
    }

    var response = await request.close();
    HttpResponse ret = HttpResponse(response.statusCode);
    await for (var contents in response.transform(Utf8Decoder())) {
      if (ret == null) {
        ret = contents;
      } else {
        ret += contents;
      }
    }

    return ret;
  }
}
