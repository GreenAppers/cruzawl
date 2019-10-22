// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:cruzawl/network/websocket.dart';
import 'package:cruzawl/util.dart';

/// dart:io [WebSocket] implementation.
class WebSocketImpl extends WebSocket {
  static const String type = 'io';

  io.WebSocket socket;

  @override
  void close() {
    if (socket != null) socket.close();
  }

  @override
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) async {
    if (!ignoreBadCert || !address.startsWith('wss://')) {
      return io.WebSocket.connect(address)
          .timeout(Duration(seconds: timeoutSeconds))
          .then((io.WebSocket x) => onConnected((socket = x)),
              onError: (error, _) => onError(error));
    }

    io.HttpClient client = io.HttpClient();
    client.badCertificateCallback =
        (io.X509Certificate cert, String host, int port) => true;

    /// Upgrade https to wss using [badCertificateCallback] to allow
    /// self-signed certificates.  This still gains you stream encryption.
    try {
      io.HttpClientRequest request =
          await client.getUrl(Uri.parse('https' + address.substring(3)));
      request.headers.add('Connection', 'upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('sec-websocket-version', '13');
      request.headers.add('sec-websocket-key', base64.encode(randBytes(8)));

      io.HttpClientResponse response = await request.close()
        ..timeout(Duration(seconds: timeoutSeconds));

      socket = io.WebSocket.fromUpgradedSocket(await response.detachSocket(),
          serverSide: false);
      onConnected(socket);
    } catch (error) {
      onError(error);
    }
  }

  @override
  void handleError(Function errorHandler) =>
      socket.handleError((error, _) => errorHandler(error));

  @override
  void handleDone(Function doneHandler) => socket.done.then(doneHandler);

  @override
  void listen(Function messageHandler) => socket.listen(messageHandler);

  @override
  void send(String text) => socket.addUtf8Text(utf8.encode(text));
}
