// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh/socket.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

typedef RawCallback = void Function(Uint8List);
typedef JsonCallback = void Function(Map<String, dynamic>);

typedef PeerStateChangedCallback = void Function(Peer, PeerState, PeerState);

enum PeerState { ready, connected, connecting, disconnected }

/// Interface for [PeerNetwork] element providing Peer API.
abstract class Peer {
  /// The persisted record defining this [Peer].
  PeerPreference spec;

  /// The connection state of this [Peer].
  PeerState state = PeerState.disconnected;

  /// Sends subscriber updates on [state] change.
  PeerStateChangedCallback stateChanged;

  /// Notifies that a new [Block] was mined.
  VoidCallback tipChanged;

  /// [Timer] to reconnection this [Peer]. Unused with [PeerNetwork] reconnect.
  Timer connectTimer;

  // Maximum number of in-flight queries.
  int maxOutstanding = 20;

  /// Optional user agent to identify local version.
  String userAgent;

  /// [Queue] of subscribers waiting for [numOutstanding] to decrease.
  Queue<Completer<void>> throttleQueue = Queue<Completer<void>>();

  /// Create [Peer] fully specified by [PeerPreference].
  Peer(this.spec);

  /// URI for [Peer].
  Uri get address;

  /// Number of in-flight queries.
  int get numOutstanding;

  /// [BlockHeader.height] of the most recently mined [Block].
  int get tipHeight;

  /// [BlockId] of the most recently mined [Block].
  BlockId get tipId;

  /// The minimum [Transaction.amount] that the network allows.
  num get minAmount;

  /// The minimum [Transaction.fee] that the network allows.
  num get minFee;

  /// Connect the [Peer]. e.g. with [WebSocket.connect].
  void connect();

  /// Disconnect the [Peer]. e.g. with [WebSocket.close].
  void disconnect(String reason);

  /// Retrieves [address]' spendable balance.
  Future<num> getBalance(PublicAddress address);

  /// Iterates [address]' transactions by height.
  Future<TransactionIteratorResults> getTransactions(
      PublicAddress address, TransactionIterator iterator,
      {int limit});

  /// Adds [transaction] to the network.
  Future<TransactionId> putTransaction(Transaction transaction);

  /// Subscribes [transactionCb] to updates on [Transaction] involving [address].
  Future<bool> filterAdd(
      PublicAddress address, TransactionCallback transactionCb);

  /// Filters uncomfirmed transactions for the [fitlerAdd()] set.
  Future<bool> filterTransactionQueue();

  /// Returns the [BlockHeader] with [id] or [height].
  Future<BlockHeaderMessage> getBlockHeader({BlockId id, int height});

  /// Returns the [Block] with [id] or [height].
  Future<BlockMessage> getBlock({BlockId id, int height});

  /// Returns the [Transaction] with [id].
  Future<TransactionMessage> getTransaction(TransactionId id);

  /// The [StateSetter] for [PeerState].
  void setState(PeerState x) {
    PeerState oldState = state;
    state = x;
    if (stateChanged != null) stateChanged(this, oldState, state);
  }

  /// Restart [connectTimer] that eventually will [connect].
  void connectAfter(int seconds) {
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = Timer(Duration(seconds: seconds), connect);
  }

  /// Context for handling received messages.
  void handleProtocol(VoidCallback cb) {
    try {
      cb();
    } catch (error, stacktrace) {
      disconnect('protocol error: $error $stacktrace');
    }
  }

  /// Disconnect and reset.  Idempotent.
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

  /// Dequeue as much of [throttleQueue] as we can.
  void dispatchFromThrottleQueue() {
    if (throttleQueue.isNotEmpty &&
        (numOutstanding ?? maxOutstanding) < maxOutstanding) {
      (throttleQueue.removeFirst()).complete(this);
    }
  }

  /// Complete [throttleQueue] with null and discard it.
  void failThrottleQueue() {
    if (spec.debugPrint != null) {
      spec.debugPrint('$address: failThrottleQueue');
    }
    while (throttleQueue.isNotEmpty) {
      (throttleQueue.removeFirst()).complete(null);
    }
  }
}

/// Socket based [Peer] interface.
abstract class SocketClient extends Peer {
  SocketInterface get socket;

  /// The URI for [Peer.connect].
  @override
  Uri address;

  /// Automatically attempt reconnecting this [Peer].
  int autoReconnectSeconds;

  /// [address] is derived from [spec] with optional context, e.g. genesis [BlockId].
  SocketClient(PeerPreference spec, this.address, {this.autoReconnectSeconds})
      : super(spec);

  /// Interface for newly established connection.
  void handleConnected();

  /// Interface for lost connection.
  void handleDisconnected();

  /// Interface for messages received from transport.
  void handleMessage(Uint8List message);

  /// Interface for managing response [JsonCallback].
  void addOutstandingJson(Map<String, dynamic> x,
      [JsonCallback responseCallback]);

  /// Inteface for reseting in-flight queries.
  void failOutstanding();

  @override
  void disconnect(String reason) {
    socket.close();
    if (spec.debugPrint != null) spec.debugPrint('Peer disconnected: $reason');
    setState(PeerState.disconnected);
    handleDisconnected();
    failOutstanding();
    failThrottleQueue();
    if (autoReconnectSeconds != null) connectAfter(autoReconnectSeconds);
  }

  void onConnected() {
    socket.handleError((error) => disconnect('SocketClient.error: $error'));
    socket.handleDone((v) => disconnect('SocketClient.done: $v'));
    socket.listen((message) => handleMessage(message));

    setState(PeerState.connected);
    if (spec.debugPrint != null) spec.debugPrint('SocketClient.onConnected');
    handleConnected();
  }

  /// [ConnectionInterface.send] message [x] expecting an in-order response for [responseCallback]
  void addJsonMessage(Map<String, dynamic> x, [JsonCallback responseCallback]) {
    addOutstandingJson(x, responseCallback);
    String message = jsonEncode(x);
    if (spec.debugPrint != null && spec.debugLevel >= debugLevelDebug) {
      spec.debugPrint('SocketClient.send: $message');
    }
    socket.send(message);
  }
}

/// Interface controlling (re)connection policy for a collection of [Peer]s.
/// Defines a type of network via [createPeerWithSpec], e.g. [CruzPeerNetwork].
abstract class PeerNetwork {
  /// The [Currency] for this network.
  Currency currency;

  /// The [Peer] we've connected to.
  List<Peer> peers = <Peer>[];

  /// The [Peer] we're trying to connect to.
  List<Peer> connecting = <Peer>[];

  /// [Queue] of subscribes waiting for a [Peer].
  Queue<Completer<Peer>> awaitingPeers = Queue<Completer<Peer>>();

  /// Notifies on any changes to [peers].
  VoidCallback peerChanged;

  /// Notifies when new [Blocks] are mined.
  VoidCallback tipChanged;

  /// Triggers [reconnectPeer] on [PeerState.disconnected].
  int autoReconnectSeconds;

  /// Optional user agent to identify local version.
  String userAgent;

  PeerNetwork(this.peerChanged, this.tipChanged,
      {this.autoReconnectSeconds = 15, this.userAgent});

  /// Supported connection types.
  List<String> get peerTypes => null;

  /// True if a [Peer] is connected.
  bool get hasPeer => peers.isNotEmpty;

  /// Number of [Peer] either [connecting] or connected.
  int get length => peers.length + connecting.length;

  /// [Block.height] of the most recently mined [Block].
  int get tipHeight => hasPeer ? peers[0].tipHeight : 0;

  /// [BlockId] of the most recently mined [Block].
  BlockId get tipId => hasPeer ? peers[0].tipId : null;

  /// The minimum [Transaction.amount] that the network allows.
  num get minAmount => hasPeer ? peers[0].minAmount : null;

  /// The minimum [Transaction.fee] that the network allows.
  num get minFee => hasPeer ? peers[0].minFee : null;

  /// [Peer.state] from [peers] or [PeerState.disconnected] if none.
  PeerState get peerState => hasPeer
      ? peers[0].state
      : (connecting.isNotEmpty ? connecting[0].state : PeerState.disconnected);

  /// [Peer.address] from [peers] or empty [String] if none.
  Uri get peerAddress => hasPeer
      ? peers[0].address
      : (connecting.isNotEmpty ? connecting[0].address : null);

  /// [Peer] factory interface.
  Peer createPeerWithSpec(PeerPreference spec);

  /// Subscribe [Peer.setState] handler [peerStateChanged].
  Peer addPeer(Peer x) {
    x.stateChanged = peerStateChanged;
    x.tipChanged = () {
      if (tipChanged != null) tipChanged();
    };
    if (x.state != PeerState.ready) {
      connecting.add(x);
    } else {
      peerBecameReady(x);
    }
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
    if (peers.isEmpty) {
      if (!wait) return null;

      Completer<Peer> completer = Completer<Peer>();
      awaitingPeers.add(completer);
      return completer.future;
    }
    final Peer peer = peers[Random().nextInt(peers.length)];
    return peer.throttle();
  }

  /// Cycles through [connecting] in round-robin fashion.
  /// Triggers only call to [WebSocket.connect] this class makes.
  void reconnectPeer() {
    assert(connecting.isNotEmpty);
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
      if (autoReconnectSeconds != null) {
        reconnectPeer();
      } else if (peers.isEmpty) {
        lostLastPeer();
      }
    }
  }

  /// lostLastPeer and [peerBecameReady] have the only calls to [peerChanged].
  void lostLastPeer() {
    if (peerChanged != null) peerChanged();
  }

  /// Notify [awaitingPeers] and [peerChanged] subscribers of a new [Peer].
  void peerBecameReady(Peer x) {
    peers.add(x);
    while (awaitingPeers.isNotEmpty) {
      (awaitingPeers.removeFirst()).complete(x);
    }
    if (peerChanged != null) peerChanged();
  }

  /// Disconnect from and clear [peers] and [connecting].
  /// [awaitingPeers] is unaffected.
  void shutdown() {
    List<Peer> oldPeers = peers, oldConnecting = connecting;
    peers = <Peer>[];
    connecting = <Peer>[];
    for (Peer peer in oldPeers) {
      removePeer(peer);
    }
    for (Peer peer in oldConnecting) {
      removePeer(peer);
    }
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

/// Interface for message with [TransactionId] and [Transaction].
class TransactionMessage {
  TransactionId id;
  Transaction transaction;
  TransactionMessage(this.id, this.transaction);
}

/// Interface for iterating [Transaction] for [PublicAddress] by [height].
class TransactionIterator {
  int height, index;
  TransactionIterator(this.height, this.index);

  /// True when the [Transaction] for [PublicAddress] have been fully traversed.
  bool get done => height == 0 && index == 0;
}

/// Interface for [TransactionIterator] results.
class TransactionIteratorResults extends TransactionIterator {
  List<Transaction> transactions;
  TransactionIteratorResults(int height, int index, this.transactions)
      : super(height, index);
  TransactionIteratorResults.empty() : this(0, 0, List<Transaction>());
}

/// Filters [networks] for a [PeerNetwork] with [Currency] matching [x].
PeerNetwork findPeerNetworkForCurrency(List<PeerNetwork> networks, Currency x) {
  if (networks == null) return null;
  return networks.singleWhere((n) => n.currency == x, orElse: () => null);
}
