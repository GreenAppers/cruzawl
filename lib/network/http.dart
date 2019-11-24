// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dartssh/client.dart';
export 'package:dartssh/http.dart';
import 'package:dartssh/http.dart';
import 'package:dartssh/identity.dart';
import 'package:dartssh/pem.dart';
import 'package:dartssh/socket_html.dart'
    if (dart.library.io) 'package:dartssh/socket_io.dart';
import 'package:dartssh/ssh.dart';

import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

/// [Peer] connected via [peerClient], optionally over SSH tunnel.
abstract class HttpClientPeer extends Peer {
  /// The URI for [Peer.connect].
  @override
  Uri address;

  /// The HTTP client communicating with [Peer].
  HttpClient peerClient;

  /// The default HTTP client.
  HttpClient rootClient;

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  HttpClientPeer(PeerPreference spec, this.address, this.rootClient)
      : peerClient = rootClient,
        super(spec);

  /// Number of outstanding requests for throttling.
  int get numOutstanding => peerClient.numOutstanding;

  /// Interface for newly established connection.
  void handleConnected();

  /// Interface for lost connection.
  void handleDisconnected();

  @override
  void disconnect(String reason) {
    if (spec.debugPrint != null) spec.debugPrint('disconnected: ' + reason);
    peerClient = rootClient;
  }

  @override
  void connect() {
    if (spec.debugPrint != null) {
      spec.debugPrint(
          'Connecting to $address ' + (spec.ignoreBadCert ? '' : 'securely'));
    }
    if (spec.sshUrl != null &&
        spec.sshUser != null &&
        (spec.sshKey != null || spec.sshPassword != null)) {
      Identity identity = spec.sshKey == null ? null : parsePem(spec.sshKey);
      SSHClient ssh = SSHClient(
          hostport: parseUri(spec.sshUrl),
          login: spec.sshUser,
          getPassword: spec.sshPassword == null
              ? null
              : () => utf8.encode(spec.sshPassword),
          loadIdentity: () => identity,
          response: (_, m) {},
          success: handleConnected,
          disconnected: () => disconnect('lost SSH connection'),
          startShell: false,
          print: print,
          debugPrint: spec.debugPrint);
      peerClient =
          HttpClientImpl(clientFactory: () => SSHTunneledBaseClient(ssh));
    } else {
      peerClient = rootClient;
      handleConnected();
    }
  }
}

/// [Peer] mixin handling HTTP responses.
mixin HttpClientMixin {
  /// HTTP client.
  HttpClient httpClient;

  /// e.g. https://blockchain.info
  Uri httpAddress;

  /// Number of outstanding requests for throttling.
  int get numOutstanding => httpClient.numOutstanding;

  VoidCallback responseComplete;

  void completeResponse<X>(Completer<X> completer, X result) {
    completer.complete(result);
    if (responseComplete != null) responseComplete();
  }
}
