// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';

import 'package:dartssh/client.dart';
export 'package:dartssh/serializable.dart' hide equalUint8List;
import 'package:dartssh/socket.dart';
import 'package:dartssh/socket_html.dart'
    if (dart.library.io) 'package:dartssh/socket_io.dart';
import 'package:dartssh/websocket_html.dart'
    if (dart.library.io) 'package:dartssh/websocket_io.dart';
import 'package:dartssh/ssh.dart' as ssh show parseUri;

import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';

/// [Peer] connected on [socket].
abstract class PersistentSocketClient extends SocketClient {
  /// Only avaiable with dart:io.
  @override
  SocketInterface socket;

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  PersistentSocketClient(PeerPreference spec, Uri uri,
      {int autoReconnectSeconds})
      : super(spec, uri, autoReconnectSeconds: autoReconnectSeconds);

  @override
  void disconnect(String reason) {
    if (socket != null) {
      super.disconnect(reason);
      socket = null;
    }
  }

  @override
  void connect() {
    if (socket == null) {
      if (spec.sshUrl != null &&
          spec.sshUser != null &&
          (spec.sshKey != null || spec.sshPassword != null)) {
        socket = SSHTunneledSocketImpl(ssh.parseUri(spec.sshUrl), spec.sshUser,
            spec.sshKey, spec.sshPassword,
            print: spec.debugPrint, debugPrint: spec.debugPrint);
        //socket = SocketImpl(SSHTunneledSocket(socket));
        if (address.hasScheme && address.scheme == 'ws') {
          socket = SSHTunneledWebSocketImpl(socket);
        }
      } else if (address.hasScheme &&
          (address.scheme == 'ws' || address.scheme == 'wss')) {
        socket = WebSocketImpl();
      } else {
        socket = SocketImpl();
      }
    }
    setState(PeerState.connecting);
    if (spec.debugPrint != null) {
      spec.debugPrint(
          'Connecting to $address ' + (spec.ignoreBadCert ? '' : 'securely'));
    }
    socket.connect(address, onConnected, (error) => disconnect('connect error'),
        ignoreBadCert: spec.ignoreBadCert);
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

  void addOutstandingRaw(Uint8List x, [RawCallback responseCallback]) {
    if (responseCallback != null) rawResponseQueue.add(responseCallback);
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
