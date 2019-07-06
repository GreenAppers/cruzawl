// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

class WebSocket {
  static const String type = 'none';

  void close() {}

  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15}) {}

  void handleError(Function errorHandler) {}

  void handleDone(Function doneHandler) {}

  void listen(Function messageHandler) {}

  void send(String text) {}
}
