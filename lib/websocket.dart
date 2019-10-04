// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:cruzawl/http.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';
import 'websocket_html.dart' if (dart.library.io) 'websocket_io.dart';

/// Interface for RFC6455 WebSocket protocol
abstract class WebSocket {
  void close();
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false});
  void handleError(Function errorHandler);
  void handleDone(Function doneHandler);
  void listen(Function messageHandler);
  void send(String text);
}

/// [Peer] mixin handling JSON responses in order.
class JsonResponseQueueMixin {
  /// [Queue] holding [JsonCallback] for expected in-order responses.
  Queue<JsonCallback> jsonResponseQueue = Queue<JsonCallback>();

  /// Number of in-flight queries.
  int get numOutstanding => jsonResponseQueue.length;

  void dispatchFromOutstanding(Map<String, dynamic> response) {
    assert(jsonResponseQueue.isNotEmpty);
    (jsonResponseQueue.removeFirst())(response);
  }

  void failOutstanding() {
    while (jsonResponseQueue.isNotEmpty) {
      (jsonResponseQueue.removeFirst())(null);
    }
  }

  void addOutstandingJson(Map<String, dynamic> x,
      [JsonCallback responseCallback]) {
    if (responseCallback != null) jsonResponseQueue.add(responseCallback);
  }
}

/// [Peer] mixin handling JSON responses indexed by query number.
class JsonResponseMapMixin {
  /// [Map] associating [JsonCallback] and response-id.
  Map<int, JsonCallback> jsonResponseMap = Map<int, JsonCallback>();

  String queryNumberField;

  int nextQueryNumber = 1;

  /// Number of in-flight queries.
  int get numOutstanding => jsonResponseMap.length;

  void dispatchFromOutstanding(Map<String, dynamic> response) {
    assert(jsonResponseMap.isNotEmpty);
    int queryId = response[queryNumberField];
    assert(queryId != null);
    JsonCallback cb = jsonResponseMap[queryId];
    assert(cb != null);
    cb(response);
  }

  void failOutstanding() {
    while (jsonResponseMap.isNotEmpty) {
      (jsonResponseMap.remove(jsonResponseMap.keys.first))(null);
    }
  }

  void addOutstandingJson(Map<String, dynamic> x,
      [JsonCallback responseCallback]) {
    if (responseCallback != null) {
      int queryNumber = nextQueryNumber++;
      jsonResponseMap[queryNumber] = responseCallback;
      x[queryNumberField] = queryNumber;
    }
  }
}

/// [Peer] integrating [html.Websocket] and [io.WebSocket]
abstract class PersistentWebSocketClient extends Peer {
  /// The URI for [WebSocket.connect]
  String address;

  /// Automatically attempt reconnecting this [Peer].
  int autoReconnectSeconds;

  /// The wrapped dart:html or dart:io [WebSocket].
  WebSocket ws = WebSocketImpl();

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

  /// Interface for managing response [JsonCallback].
  void addOutstandingJson(Map<String, dynamic> x,
      [JsonCallback responseCallback]);

  /// Inteface for reseting in-flight queries.
  void failOutstanding();

  @override
  void disconnect(String reason) {
    ws.close();
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
  void addJsonMessage(Map<String, dynamic> x, [JsonCallback responseCallback]) {
    addOutstandingJson(x, responseCallback);
    String message = jsonEncode(x);
    if (spec.debugPrint != null && spec.debugLevel >= debugLevelDebug) {
      spec.debugPrint('sending message: $message');
    }
    ws.send(message);
  }
}

/// Shim [WebSocket] for testing
class TestWebSocket extends WebSocket {
  bool connected = false, closed = false;
  Function messageHandler, errorHandler, doneHandler;
  Queue<String> sent = Queue<String>();

  void close() => closed = true;

  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) {
    connected = true;
    closed = false;
    onConnected(this);
  }

  void handleError(Function errorHandler) => this.errorHandler = errorHandler;
  void handleDone(Function doneHandler) => this.doneHandler = doneHandler;
  void listen(Function messageHandler) => this.messageHandler = messageHandler;
  void send(String text) => sent.add(text);
}
