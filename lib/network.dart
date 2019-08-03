// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

typedef PeerStateChangedCallback = void Function(Peer, PeerState, PeerState);

enum PeerState { ready, connected, connecting, disconnected }

/// Interface for [PeerNetwork] element providing [Peer] API
abstract class Peer {
  PeerPreference spec;
  PeerState state = PeerState.disconnected;
  PeerStateChangedCallback stateChanged;
  VoidCallback tipChanged;
  Timer connectTimer;
  int maxOutstanding = 20;
  Queue<Completer<void>> throttleQueue = Queue<Completer<void>>();
  Peer(this.spec);

  String get address;
  BlockId get tipId;
  BlockHeader get tip;
  int get numOutstanding;
  num get minAmount;
  num get minFee;

  /// [Peer] API
  void connect();
  void disconnect(String reason);
  Future<num> getBalance(PublicAddress address);
  Future<TransactionIteratorResults> getTransactions(PublicAddress address,
      {int startHeight, int startIndex, int endHeight, int limit});
  Future<TransactionId> putTransaction(Transaction transaction);
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb);
  Future<bool> filterTransactionQueue();
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height});
  Future<BlockMessage> getBlock({BlockId id, int height});
  Future<Transaction> getTransaction(TransactionId id);

  void setState(PeerState x) {
    PeerState oldState = state;
    state = x;
    if (stateChanged != null) stateChanged(this, oldState, state);
  }

  void close() {
    if (state != PeerState.disconnected) disconnect('Peer close');
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = null;
  }

  void connectAfter(int seconds) {
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = Timer(Duration(seconds: seconds), connect);
  }

  Future<Peer> throttle() async {
    if (numOutstanding < maxOutstanding) return this;
    Completer<Peer> completer = Completer();
    throttleQueue.add(completer);
    return completer.future;
  }

  void dispatchFromThrottleQueue() {
    if (throttleQueue.length > 0 &&
        (numOutstanding ?? maxOutstanding) < maxOutstanding)
      (throttleQueue.removeFirst()).complete(this);
  }

  void failThrottleQueue() {
    while (throttleQueue.length > 0)
      (throttleQueue.removeFirst()).complete(null);
  }

  void handleProtocol(VoidCallback cb) {
    try {
      cb();
    } catch (error, stacktrace) {
      disconnect('protocol error: $error $stacktrace');
    }
  }
}

/// [PeerNetwork] controls (re)connection policy for a collection of [Peer]s
/// and via [createPeerWithSpec] defines a type of network, e.g. [CruzPeerNetwork]
abstract class PeerNetwork {
  int autoReconnectSeconds;
  List<Peer> peers = <Peer>[];
  List<Peer> connecting = <Peer>[];
  Queue<Completer<Peer>> awaitingPeers = Queue<Completer<Peer>>();
  VoidCallback peerChanged, tipChanged;
  PeerNetwork({this.autoReconnectSeconds = 15});

  bool get hasPeer => peers.length > 0;
  int get tipHeight => hasPeer ? tip.height : 0;
  BlockHeader get tip => hasPeer ? peers[0].tip : null;
  BlockId get tipId => hasPeer ? peers[0].tipId : null;
  num get minAmount => hasPeer ? peers[0].minAmount : null;
  num get minFee => hasPeer ? peers[0].minFee : null;
  int get length => peers.length + connecting.length;
  PeerState get peerState => hasPeer
      ? peers[0].state
      : (connecting.length > 0 ? connecting[0].state : PeerState.disconnected);
  String get peerAddress => hasPeer
      ? peers[0].address
      : (connecting.length > 0 ? connecting[0].address : '');

  /// [Peer] factory interface
  Peer createPeerWithSpec(PeerPreference spec, String genesisBlockId);

  Peer addPeer(Peer x) {
    x.stateChanged = peerStateChanged;
    x.tipChanged = () {
      if (tipChanged != null) tipChanged();
    };
    if (x.state != PeerState.ready)
      connecting.add(x);
    else
      peerReady(x);
    return x;
  }

  void removePeer(Peer x) {
    x.stateChanged = null;
    x.close();
    peers.remove(x);
    connecting.remove(x);
  }

  Future<Peer> getPeer() async {
    if (peers.length == 0) {
      Completer<Peer> completer = Completer<Peer>();
      awaitingPeers.add(completer);
      return completer.future;
    }
    final Peer peer = peers[Random().nextInt(peers.length)];
    return peer.throttle();
  }

  void peerReady(Peer x) {
    peers.add(x);
    while (awaitingPeers.length > 0) (awaitingPeers.removeFirst()).complete(x);
    if (peerChanged != null) peerChanged();
  }

  void peerStateChanged(Peer x, PeerState oldState, PeerState newState) {
    if (newState == PeerState.ready && oldState != PeerState.ready) {
      connecting.remove(x);
      peerReady(x);
    } else if (newState != PeerState.ready && oldState == PeerState.ready) {
      peers.remove(x);
      connecting.add(x);
    }
    if (newState == PeerState.disconnected) {
      if (autoReconnectSeconds != null)
        reconnectPeer();
      else if (peers.length == 0 && peerChanged != null) peerChanged();
    }
  }

  void reconnectPeer() {
    assert(connecting.length > 0);
    Peer x = connecting.removeAt(0);
    x.connectAfter(autoReconnectSeconds);
    connecting.add(x);
  }

  void reset() {
    List<Peer> oldPeers = peers, oldConnecting = connecting;
    peers = <Peer>[];
    connecting = <Peer>[];
    for (Peer peer in oldPeers) removePeer(peer);
    for (Peer peer in oldConnecting) removePeer(peer);
  }
}
