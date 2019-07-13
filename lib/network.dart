// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:json_annotation/json_annotation.dart';

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/util.dart';

part 'network.g.dart';

typedef PeerStateChangedCallback = void Function(Peer, PeerState, PeerState);

enum PeerState { ready, connected, connecting, disconnected }

@JsonSerializable()
class PeerPreference {
  String name, url, currency, options;
  int priority = 100;

  @JsonKey(ignore: true)
  StringCallback debugPrint;

  PeerPreference(this.name, this.url, this.currency, this.options,
      {this.debugPrint});

  factory PeerPreference.fromJson(Map<String, dynamic> json) =>
      _$PeerPreferenceFromJson(json);

  Map<String, dynamic> toJson() => _$PeerPreferenceToJson(this);

  bool get ignoreBadCert =>
      options != null && options.contains(',ignoreBadCert,');

  static String formatOptions({bool ignoreBadCert = false}) {
    String options = ',';
    if (ignoreBadCert) options += 'ignoreBadCert,';
    return options;
  }

  static int comparePriority(dynamic a, dynamic b) => b.priority - a.priority;
}

abstract class Peer {
  PeerPreference spec;
  VoidCallback tipChanged;
  PeerStateChangedCallback stateChanged;
  PeerState state = PeerState.disconnected;
  Queue<Completer<void>> throttleQueue = Queue<Completer<void>>();
  int maxOutstanding = 20;
  Timer connectTimer;
  Peer(this.spec);

  String get address;
  BlockId get tipId;
  BlockHeader get tip;
  int get numOutstanding;
  num get minAmount;
  num get minFee;

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

  void setState(PeerState x) {
    PeerState oldState = state;
    state = x;
    if (stateChanged != null) stateChanged(this, oldState, state);
  }

  void connectAfter(int seconds) {
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void close() {
    if (state != PeerState.disconnected) disconnect('Peer close');
    if (connectTimer != null) connectTimer.cancel();
    connectTimer = null;
  }

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
}

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

  String parseUri(String uriText, String genesisId);

  Peer addPeerWithSpec(PeerPreference spec, String genesisBlockId);

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
