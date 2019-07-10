// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:cruzawl/util.dart';

class WebSocket {
  static const String type = 'io';

  io.WebSocket ws;

  void close() {
    if (ws != null) ws.close();
  }

  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = true}) async {
    if (!ignoreBadCert || !address.startsWith('wss://'))
      return io.WebSocket.connect(address)
          .timeout(Duration(seconds: timeoutSeconds))
          .then((io.WebSocket x) => onConnected((ws = x)),
              onError: (error, _) => onError(error));

    io.HttpClient client = io.HttpClient();
    client.badCertificateCallback =
        (io.X509Certificate cert, String host, int port) => true;

    try {
      io.HttpClientRequest request =
          await client.getUrl(Uri.parse('https' + address.substring(3)));
      request.headers.add('Connection', 'upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('sec-websocket-version', '13');
      request.headers.add('sec-websocket-key', base64.encode(randBytes(8)));

      io.HttpClientResponse response = await request.close()
        ..timeout(Duration(seconds: timeoutSeconds));

      io.Socket socket = await response.detachSocket();

      ws = io.WebSocket.fromUpgradedSocket(socket, serverSide: false);
      onConnected(ws);
    } on Exception catch (error) {
      onError(error);
    }
  }

  void handleError(Function errorHandler) =>
      ws.handleError((error, _) => errorHandler(error));

  void handleDone(Function doneHandler) => ws.done.then(doneHandler);

  void listen(Function messageHandler) => ws.listen(messageHandler);

  void send(String text) => ws.addUtf8Text(utf8.encode(text));
}
