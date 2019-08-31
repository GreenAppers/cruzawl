// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:cruzawl/websocket.dart';

/// dart:html [WebSocket] implementation.
class WebSocketImpl extends WebSocket {
  static const String type = 'html';

  html.WebSocket ws;
  Function connectCallback;
  StreamSubscription connectErrorSubscription;

  @override
  void close() => ws.close();

  @override
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) {
    /// No way to allow self-signed certificates.
    assert(!ignoreBadCert);
    try {
      connectCallback = onConnected;
      ws = html.WebSocket(address);
      ws.onOpen.listen(this.onConnected);
      connectErrorSubscription = ws.onError.listen(onError);
    } on Exception catch (error) {
      onError(error, null);
    }
  }

  void onConnected(dynamic x) {
    connectErrorSubscription.cancel();
    connectErrorSubscription = null;
    connectCallback(x);
  }

  @override
  void handleError(Function errorHandler) => ws.onError.listen(errorHandler);

  @override
  void handleDone(Function doneHandler) => ws.onClose.listen(doneHandler);

  @override
  void listen(Function messageHandler) =>
      ws.onMessage.listen((e) => messageHandler(e.data));

  @override
  void send(String text) => ws.sendString(text);
}
