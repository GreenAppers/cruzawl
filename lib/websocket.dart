// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/socket.dart';
import 'websocket_html.dart' if (dart.library.io) 'websocket_io.dart';

/// Interface for RFC6455 WebSocket protocol
abstract class WebSocket extends ConnectionInterface {
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false});
}

/// [Peer] integrating [html.Websocket] and [io.WebSocket]
abstract class PersistentWebSocketClient extends SocketClient {
  /// The wrapped dart:html or dart:io [WebSocket].
  @override
  WebSocket socket = WebSocketImpl();

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  PersistentWebSocketClient(PeerPreference spec, String address,
      {int autoReconnectSeconds})
      : super(spec, address, autoReconnectSeconds: autoReconnectSeconds);

  @override
  void disconnect(String reason) {
    socket.close();
    if (spec.debugPrint != null) spec.debugPrint('disconnected: ' + reason);
    setState(PeerState.disconnected);
    handleDisconnected();
    failOutstanding();
    failThrottleQueue();
    if (autoReconnectSeconds != null) connectAfter(autoReconnectSeconds);
  }

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

  void onConnected(dynamic x) {
    socket.handleError((error) => disconnect('socket error'));
    socket.handleDone((v) => disconnect('socket done'));
    socket.listen((message) => handleMessage(message));

    setState(PeerState.connected);
    if (spec.debugPrint != null) spec.debugPrint('onConnected');
    handleConnected();
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
