// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'websocket_html.dart' if (dart.library.io) 'websocket_io.dart';

typedef JsonCallback = void Function(Map<String, dynamic>);

/// [Peer] integrating [html.Websocket] and [io.WebSocket]
abstract class PersistentWebSocketClient extends Peer {
  /// The URI for [WebSocket.connect]
  String address;

  /// Automatically attempt reconnecting this [Peer].
  int autoReconnectSeconds;

  /// The wrapped dart:html or dart:io [WebSocket].
  WebSocket ws = WebSocket();

  /// [Queue] holding [JsonCallback] for expected in-order responses.
  Queue<JsonCallback> jsonResponseQueue = Queue<JsonCallback>();

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  PersistentWebSocketClient(PeerPreference spec, this.address,
      {this.autoReconnectSeconds})
      : super(spec);

  /// Interface for newly established connection.
  void handleConnected();

  /// Interface for lost connection.
  void handleDisconnected();

  /// Interface for messages received from transport.
  void handleMessage(String message);

  /// Number of in-flight queries.
  @override
  int get numOutstanding => jsonResponseQueue.length;

  @override
  void disconnect(String reason) {
    ws.close();
    if (spec.debugPrint != null) spec.debugPrint('disconnected: ' + reason);
    setState(PeerState.disconnected);
    handleDisconnected();
    failJsonResponseQueue();
    failThrottleQueue();
    if (autoReconnectSeconds != null) connectAfter(autoReconnectSeconds);
  }

  @override
  void connect() {
    setState(PeerState.connecting);
    if (spec.debugPrint != null)
      spec.debugPrint(
          'Connecting to $address ' + (spec.ignoreBadCert ? '' : 'securely'));
    ws.connect(address, onConnected, (error) => disconnect('connect error'),
        ignoreBadCert: spec.ignoreBadCert);
  }

  void onConnected(dynamic x) {
    ws.handleError((error) => disconnect('socket error'));
    ws.handleDone((v) => disconnect('socket done'));
    ws.listen((message) => handleMessage(message));

    setState(PeerState.connected);
    if (spec.debugPrint != null) spec.debugPrint('onConnected');
    handleConnected();
  }

  /// [WebSocket.send] message [x] expecting an in-order response for [responseCallback]
  void addJsonMessage(Map<String, dynamic> x, JsonCallback responseCallback) {
    String message = jsonEncode(x);
    if (spec.debugPrint != null) spec.debugPrint('sending message: $message');
    if (responseCallback != null) jsonResponseQueue.add(responseCallback);
    ws.send(message);
  }

  void dispatchFromJsonResponseQueue(Map<String, dynamic> response) {
    assert(jsonResponseQueue.length > 0);
    (jsonResponseQueue.removeFirst())(response);
    dispatchFromThrottleQueue();
  }

  void failJsonResponseQueue() {
    while (jsonResponseQueue.length > 0)
      (jsonResponseQueue.removeFirst())(null);
  }
}
