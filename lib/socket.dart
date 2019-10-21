// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';

import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';

import 'socket_html.dart' if (dart.library.io) 'socket_io.dart';

abstract class SocketInterface extends ConnectionInterface {
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false});
}

abstract class PersistentSocketClient extends SocketClient {
  /// Only avaiable with dart:io.
  @override
  SocketInterface socket;

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  PersistentSocketClient(PeerPreference spec, String address,
      {int autoReconnectSeconds})
      : super(spec, address, autoReconnectSeconds: autoReconnectSeconds);

  @override
  void disconnect(String reason) {}

  @override
  void connect() {
    //socket.connect(
  }
}

mixin TestConnection {
  bool connected = false, closed = false;
  Function messageHandler, errorHandler, doneHandler;
  Queue<String> sent = Queue<String>();

  void close() => closed = true;
  void handleError(Function errorHandler) => this.errorHandler = errorHandler;
  void handleDone(Function doneHandler) => this.doneHandler = doneHandler;
  void listen(Function messageHandler) => this.messageHandler = messageHandler;
  void send(String text) => sent.add(text);
}

class TestSocket extends SocketInterface with TestConnection {
  void connect(String address, Function onConnected, Function onError,
      {int timeoutSeconds = 15, bool ignoreBadCert = false}) {
    connected = true;
    closed = false;
    //onConnected(this);
  }
}

/// [Peer] mixin handling raw responses in order.
mixin RawResponseQueueMixin {
  /// [Queue] holding [RawCallback] for expected in-order responses.
  Queue<RawCallback> rawResponseQueue = Queue<RawCallback>();

  /// Number of in-flight queries.
  int get numOutstanding => rawResponseQueue.length;

  void dispatchFromOutstanding(Uint8List response) {
    assert(rawResponseQueue.isNotEmpty);
    (rawResponseQueue.removeFirst())(response);
  }

  void failOutstanding() {
    while (rawResponseQueue.isNotEmpty) {
      (rawResponseQueue.removeFirst())(null);
    }
  }

  void addOutstandingJson(Map<String, dynamic> x,
      [JsonCallback responseCallback]) {
    throw FormatException('Not implemented.');
  }
}

/// [Peer] mixin handling JSON responses in order.
mixin JsonResponseQueueMixin {
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
mixin JsonResponseMapMixin {
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
    JsonCallback cb = jsonResponseMap.remove(queryId);
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

class NullJsonResponseMixin {
  void addOutstandingJson(Map<String, dynamic> x,
      [JsonCallback responseCallback]) {}

  void failOutstanding() {}
}
