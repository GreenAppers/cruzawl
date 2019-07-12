// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

class WebSocket {
  static const String type = 'html';

  html.WebSocket ws;
  Function connectCallback;
  StreamSubscription connectErrorSubscription;

  void close() => ws.close();

  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) {
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

  void handleError(Function errorHandler) => ws.onError.listen(errorHandler);

  void handleDone(Function doneHandler) => ws.onClose.listen(doneHandler);

  void listen(Function messageHandler) =>
      ws.onMessage.listen((e) => messageHandler(e.data));

  void send(String text) => ws.sendString(text);
}
