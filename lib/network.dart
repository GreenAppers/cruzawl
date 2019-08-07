// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

enum PeerState { ready, connected, connecting, disconnected }

typedef PeerStateChangedCallback = void Function(Peer, PeerState, PeerState);

/// Interface for [PeerNetwork] element providing Peer API.
abstract class Peer {
  PeerPreference spec;
  PeerState state = PeerState.disconnected;
  PeerStateChangedCallback stateChanged;
  VoidCallback tipChanged;
  Timer connectTimer;
  int maxOutstanding = 20;
  Queue<Completer<void>> throttleQueue = Queue<Completer<void>>();
  Peer(this.spec);

  // Connection properties
  String get address;
  int get numOutstanding;

  // Network properties
  BlockId get tipId;
  BlockHeader get tip;
  num get minAmount;
  num get minFee;

  // Peer API
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

  /// Primary [StateSetter].
  void setState(PeerState x) {
    PeerState oldState = state;
    state = x;
    if (stateChanged != null) stateChanged(this, oldState, state);
  }

  // Connection handling
  void connectAfter(int seconds) {
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void handleProtocol(VoidCallback cb) {
    try {
      cb();
    } catch (error, stacktrace) {
      disconnect('protocol error: $error $stacktrace');
    }
  }

  void close() {
    if (state != PeerState.disconnected) disconnect('Peer close');
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = null;
  }

  /// Keep a [Queue] after [maxOutstanding] in-flight queries.
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
}

/// Interface controlling (re)connection policy for a collection of [Peer]s.
/// Defines a type of network via [createPeerWithSpec], e.g. [CruzPeerNetwork].
abstract class PeerNetwork {
  int autoReconnectSeconds;
  List<Peer> peers = <Peer>[];
  List<Peer> connecting = <Peer>[];
  Queue<Completer<Peer>> awaitingPeers = Queue<Completer<Peer>>();
  VoidCallback peerChanged, tipChanged;
  PeerNetwork({this.autoReconnectSeconds = 15});

  bool get hasPeer => peers.length > 0;
  int get length => peers.length + connecting.length;

  // Peer property wrappers
  int get tipHeight => hasPeer ? tip.height : 0;
  BlockHeader get tip => hasPeer ? peers[0].tip : null;
  BlockId get tipId => hasPeer ? peers[0].tipId : null;
  num get minAmount => hasPeer ? peers[0].minAmount : null;
  num get minFee => hasPeer ? peers[0].minFee : null;
  PeerState get peerState => hasPeer
      ? peers[0].state
      : (connecting.length > 0 ? connecting[0].state : PeerState.disconnected);
  String get peerAddress => hasPeer
      ? peers[0].address
      : (connecting.length > 0 ? connecting[0].address : '');

  /// [Peer] factory interface.
  Peer createPeerWithSpec(PeerPreference spec, String genesisBlockId);

  /// Subscribe [Peer.setState] handler [peerStateChanged].
  Peer addPeer(Peer x) {
    x.stateChanged = peerStateChanged;
    x.tipChanged = () {
      if (tipChanged != null) tipChanged();
    };
    if (x.state != PeerState.ready)
      connecting.add(x);
    else
      peerBecameReady(x);
    return x;
  }

  /// Unsubscribe [Peer.stateChanged] and [Peer.close].
  void removePeer(Peer x) {
    x.stateChanged = null;
    x.close();
    peers.remove(x);
    connecting.remove(x);
  }

  /// Get a random throttled [Peer] or add to reconnect [Queue] if none and [wait].
  Future<Peer> getPeer([bool wait = true]) async {
    if (peers.length == 0) {
      if (!wait) return null;

      Completer<Peer> completer = Completer<Peer>();
      awaitingPeers.add(completer);
      return completer.future;
    }
    final Peer peer = peers[Random().nextInt(peers.length)];
    return peer.throttle();
  }

  /// Makes the only call to [WebSocket.connect].
  void reconnectPeer() {
    assert(connecting.length > 0);
    Peer x = connecting.removeAt(0);
    x.connectAfter(autoReconnectSeconds);
    connecting.add(x);
  }

  /// Track [Peer.setState] triggering [reconnectPeer] or [peerChanged].
  void peerStateChanged(Peer x, PeerState oldState, PeerState newState) {
    if (newState == PeerState.ready && oldState != PeerState.ready) {
      connecting.remove(x);
      peerBecameReady(x);
    } else if (newState != PeerState.ready && oldState == PeerState.ready) {
      peers.remove(x);
      connecting.add(x);
    }

    if (newState == PeerState.disconnected) {
      if (autoReconnectSeconds != null)
        reconnectPeer();
      else if (peers.length == 0) lostLastPeer();
    }
  }

  /// lostLastPeer and [peerBecameReady] have the only calls to [peerChanged].
  void lostLastPeer() {
    if (peerChanged != null) peerChanged();
  }

  void peerBecameReady(Peer x) {
    peers.add(x);
    while (awaitingPeers.length > 0) (awaitingPeers.removeFirst()).complete(x);
    if (peerChanged != null) peerChanged();
  }

  void shutdown() {
    List<Peer> oldPeers = peers, oldConnecting = connecting;
    peers = <Peer>[];
    connecting = <Peer>[];
    for (Peer peer in oldPeers) removePeer(peer);
    for (Peer peer in oldConnecting) removePeer(peer);
  }
}

/// Interface for message with [BlockId] and [Block].
class BlockMessage {
  BlockId id;
  Block block;
  BlockMessage(this.id, this.block);
}

/// Interface for message with [BlockId] and [BlockHeader].
class BlockHeaderMessage {
  BlockId id;
  BlockHeader header;
  BlockHeaderMessage(this.id, this.header);
}

/// Interface for iterating [Transaction] for [PublicAddress] by [height].
class TransactionIterator {
  int height, index;
  TransactionIterator(this.height, this.index);
}

/// Interface for [TransactionIterator] results.
class TransactionIteratorResults extends TransactionIterator {
  List<Transaction> transactions;
  TransactionIteratorResults(int height, int index, this.transactions)
      : super(height, index);
}
