// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:dartssh/socket.dart';

import 'package:cruzawl/network.dart';
import 'package:cruzawl/network/socket.dart';
import 'package:cruzawl/network/websocket_html.dart'
    if (dart.library.io) 'package:cruzawl/network/websocket_io.dart';
import 'package:cruzawl/preferences.dart';

/// Interface for RFC6455 WebSocket protocol.
abstract class WebSocket extends ConnectionInterface {
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false});
}

/// [Peer] integrating [html.Websocket] and [io.WebSocket].
abstract class PersistentWebSocketClient extends SocketClient {
  /// The wrapped dart:html or dart:io [WebSocket].
  @override
  WebSocket socket = WebSocketImpl();

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  PersistentWebSocketClient(PeerPreference spec, String address,
      {int autoReconnectSeconds})
      : super(spec, address, autoReconnectSeconds: autoReconnectSeconds);

  @override
  void connect() {
    setState(PeerState.connecting);
    if (spec.debugPrint != null) {
      spec.debugPrint(
          'Connecting to $address ' + (spec.ignoreBadCert ? '' : 'securely'));
    }
    socket.connect(address, onConnected, (error) => disconnect('connect error'),
        ignoreBadCert: spec.ignoreBadCert);
  }
}

/// Shim [WebSocket] for testing
class TestWebSocket extends WebSocket with TestConnection {
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) {
    connected = true;
    closed = false;
    onConnected(this);
  }
}
