// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

export 'http_html.dart' if (dart.library.io) 'http_io.dart';

/// HTTP response itegrating [io.HttpClient] and [html.HttpRequest].
class HttpResponse {
  int status;
  String text;
  HttpResponse(this.status, [this.text]);
}
