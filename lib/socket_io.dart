// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cruzawl/socket.dart';

class SocketImpl extends SocketInterface {
  Socket socket;

  void close() {}
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) {}
  void handleError(Function errorHandler) {}
  void handleDone(Function doneHandler) {}
  void listen(Function messageHandler) {}
  void send(String text) {}
}
