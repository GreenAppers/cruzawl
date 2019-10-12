// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tweetnacl_musig/tweetnacl_musig.dart';

import 'package:cruzawl/currency.dart' hide PrivateKey;
import 'package:cruzawl/cruz.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/test.dart';
import 'package:cruzawl/websocket_html.dart'
    if (dart.library.io) 'package:cruzawl/websocket_io.dart';

void main() {
  CruzTester(group, test, expect).run();
  CruzWalletTester(group, test, expect).run();

  test('CRUZ currency', () {
    Currency currency = cruz;
    expect(CRUZ.blocksUntilNewSeries, 1008);
    expect(CRUZ.cruzbitsPerCruz, 100000000);
    expect(CRUZ.initialCoinbaseReward, 50);
    expect(CRUZ.blocksUntilRewardHalving, 210000);
    expect(CruzPublicKey.size, 32);
    expect(CruzPrivateKey.size, 64);
    expect(CruzSignature.size, 64);
    expect(CruzChainCode.size, 32);
    expect(CruzTransactionId.size, 32);
    expect(CruzBlockId.size, 32);

    expect(
        currency
            .fromBlockIdJson(
                '00000000000555de1d28a55fd2d5d2069c61fd46c4618cfea16c5adf6d902f4d')
            .toJson(),
        currency
            .fromBlockIdJson(
                '555de1d28a55fd2d5d2069c61fd46c4618cfea16c5adf6d902f4d', true)
            .toJson());
    expect(
        currency
            .fromTransactionIdJson(
                '0000cb989226cc52493ca92754acda383e0b483ac433e9216f53f13be3570459',
                true)
            .toJson(),
        currency
            .fromTransactionIdJson(
                'cb989226cc52493ca92754acda383e0b483ac433e9216f53f13be3570459',
                true)
            .toJson());

    expect(currency.nullAddress.toJson(),
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
    expect(currency.suggestedFee(null), '0.01');
    expect(currency.parse(currency.suggestedFee(null)), 1000000);
    expect(currency.supply(210033), 10500825);
  });

  test('LoadingCurrency', () {
    Currency currency = loadingCurrency;

    expect(currency.ticker, cruz.ticker);
    expect(currency.parse('33'), 33);
    expect(currency.parseTime(43), DateTime.fromMillisecondsSinceEpoch(43000));
    expect(currency.supply(53), null);
    expect(currency.blockCreationReward(63), null);
    expect(currency.bip44CoinType, 0);
    expect(currency.coinbaseMaturity, 0);
    expect(currency.nullAddress, null);
    expect(currency.createNetwork(), null);
    expect(currency.genesisBlock(), null);
    expect(currency.deriveAddress(null, null), null);
    expect(currency.fromPrivateKey(null), null);
    expect(currency.fromPublicKey(null), null);
    expect(currency.fromAddressJson(null), null);
    expect(currency.fromPublicAddressJson(null), null);
    expect(currency.fromPrivateKeyJson(null), null);
    expect(currency.fromBlockIdJson(null), null);
    expect(currency.fromTransactionIdJson(null), null);
    expect(currency.fromTransactionJson(null), null);
    expect(currency.suggestedFee(null), null);
    expect(
        currency.signedTransaction(null, null, null, null, null, null), null);
  });

  test('WebSocket connection to public seeder - require valid cert', () async {
    expect(WebSocketImpl.type, 'io');
    Completer<void> completer = Completer<void>();
    PeerNetwork network = cruz.createNetwork();
    network.tipChanged = () => completer.complete(null);
    network.addPeer(network.createPeerWithSpec(
        PeerPreference('SatoshiLocomoco', 'wallet.cruzbit.xyz', 'CRUZ', '',
            debugPrint: (x) {/* print('DEBUG: $x'); */})))
      ..connectAfter(1)
      ..connectAfter(0);
    await completer.future;
    print('Found live tip height = ${network.tipHeight}');
    expect(network.tipHeight > 0, true);
    network.shutdown();
  });

  test('WebSocket connection to public seeder - ignore bad cert', () async {
    Completer<void> completer = Completer<void>();
    PeerNetwork network = cruz.createNetwork();
    network.autoReconnectSeconds = 0;
    network.tipChanged = () => completer.complete(null);
    Peer peer = network.addPeer(network.createPeerWithSpec(PeerPreference(
        'SatoshiLocomoco',
        'wallet.cruzbit.xyz',
        'CRUZ',
        PeerPreference.formatOptions(ignoreBadCert: true),
        debugPrint: (x) {/* print('DEBUG: $x'); */})));
    network.peerStateChanged(
        peer, PeerState.connecting, PeerState.disconnected);

    await completer.future;
    print('Found live tip height = ${network.tipHeight}');
    expect(network.tipHeight > 0, true);
    network.shutdown();
  });

  /// https://github.com/HyperspaceApp/atomicswap
  test('cruz1-to-cruz2 atomic swap', () {
    /// cruz1 -> cruz2 exchange rate = 1.3.
    num aliceSendsBobCruz1 = cruz.parse('10'),
        bobSendsAliceCruz2 = cruz.parse('13');
    int cruz1height = 40000, cruz2height = 824929;
    int cruz1fee = cruz.parse(cruz.suggestedFee(null)), cruz2fee = cruz1fee;
    int oneDayInBlocks = 6 * 24;

    /// Alice generates Keypair1 for cruz1 and Keypair2 for cruz2.
    final PrivateKey alicePriv1 = PrivateKey.fromSeed(randBytes(32));
    final PrivateKey alicePriv2 = PrivateKey.fromSeed(randBytes(32));
    final PublicKey alicePub1 = alicePriv1.publicKey,
        alicePub2 = alicePriv2.publicKey;

    /// Alice sends Bob [alicePub2] ------------------------------------------>.

    /// Bob generates Keypair1 for cruz1 and Keypair2 for cruz2.
    final PrivateKey bobPriv1 = PrivateKey.fromSeed(randBytes(32));
    final PrivateKey bobPriv2 = PrivateKey.fromSeed(randBytes(32));
    final PublicKey bobPub1 = bobPriv1.publicKey, bobPub2 = bobPriv2.publicKey;

    /// <-------------------------------------------- Bob sends Alice [bobPub1].

    /// Bob creates [bobJointKey2].
    final JointKey bobJointKey2 =
        JointKey.generate(<PublicKey>[alicePub2, bobPub2], bobPriv2, 1);

    /// Alice creates [aliceJointKey1].
    final JointKey aliceJointKey1 =
        JointKey.generate(<PublicKey>[alicePub1, bobPub1], alicePriv1, 0);

    /// Alice sends Bob [aliceFundingTransaction1] --------------------------->.
    final CruzTransaction aliceFundingTransaction1 = CruzTransaction(
        CruzPublicKey(alicePub1.data),
        CruzPublicKey(aliceJointKey1.jointPublicKey.data),
        aliceSendsBobCruz1 + cruz1fee,
        cruz1fee,
        null,
        seriesForHeight: cruz1height);

    /// Alice sends Bob [aliceRefundTransaction1] and [aliceRefundR1] -------->.
    final CruzTransaction aliceRefundTransaction1 = CruzTransaction(
        CruzPublicKey(aliceJointKey1.jointPublicKey.data),
        CruzPublicKey(alicePub1.data),
        aliceSendsBobCruz1,
        cruz1fee,
        null,
        seriesForHeight: cruz1height,
        matures: cruz1height + oneDayInBlocks);
    final Uint8List aliceRefundr1 =
        generateNonce(alicePriv1, aliceRefundTransaction1.id().data);
    final CurvePoint aliceRefundR1 = CurvePoint.fromScalar(aliceRefundr1);

    /// Alice sends Bob [bobClaimTransaction1] and [aliceBobClaimR1] --------->.
    final CruzTransaction bobClaimTransaction1 = CruzTransaction(
        CruzPublicKey(aliceJointKey1.jointPublicKey.data),
        CruzPublicKey(bobPub1.data),
        aliceSendsBobCruz1,
        cruz1fee,
        null,
        seriesForHeight: cruz1height,
        expires: cruz1height + oneDayInBlocks);
    final Uint8List aliceBobClaimr1 =
        generateNonce(alicePriv1, bobClaimTransaction1.id().data);
    final CurvePoint aliceBobClaimR1 = CurvePoint.fromScalar(aliceBobClaimr1);

    /// <--------------------------- Bob sends Alice [bobFundingTransaction2].
    final CruzTransaction bobFundingTransaction2 = CruzTransaction(
        CruzPublicKey(bobPub2.data),
        CruzPublicKey(bobJointKey2.jointPublicKey.data),
        bobSendsAliceCruz2 + cruz2fee,
        cruz2fee,
        null,
        seriesForHeight: cruz2height);

    /// <------------ Bob sends Alice [bobRefundTransaction2] and [bobRefundR2].
    final CruzTransaction bobRefundTransaction2 = CruzTransaction(
        CruzPublicKey(bobJointKey2.jointPublicKey.data),
        CruzPublicKey(bobPub2.data),
        bobSendsAliceCruz2,
        cruz2fee,
        null,
        seriesForHeight: cruz2height,
        matures: cruz2height + oneDayInBlocks * 2);
    final Uint8List bobRefundr2 =
        generateNonce(bobPriv2, bobRefundTransaction2.id().data);
    final CurvePoint bobRefundR2 = CurvePoint.fromScalar(bobRefundr2);

    /// <--------- Bob sends Alice [aliceClaimTransaction2] and [bobAliceClaimR2].
    final CruzTransaction aliceClaimTransaction2 = CruzTransaction(
        CruzPublicKey(bobJointKey2.jointPublicKey.data),
        CruzPublicKey(alicePub2.data),
        bobSendsAliceCruz2,
        cruz2fee,
        null,
        seriesForHeight: cruz2height,
        expires: cruz2height + oneDayInBlocks * 2);
    final Uint8List bobAliceClaimr2 =
        generateNonce(bobPriv2, aliceClaimTransaction2.id().data);
    final CurvePoint bobAliceClaimR2 = CurvePoint.fromScalar(bobAliceClaimr2);

    /// <------------------ Bob generates [bobRefundAliceR1] and sends to Alice.
    final bobRefundAlicer1 =
        generateNonce(bobPriv1, aliceRefundTransaction1.id().data);
    final CurvePoint bobRefundAliceR1 = CurvePoint.fromScalar(bobRefundAlicer1);

    /// Alice generates [aliceClaimR2] and sends to Bob ---------------------->.
    final aliceClaimr2 =
        generateNonce(alicePriv2, aliceClaimTransaction2.id().data);
    final CurvePoint aliceClaimR2 = CurvePoint.fromScalar(aliceClaimr2);

    /// Alice generates [aliceRefundBobR2] and sends to Bob ------------------>.
    final aliceRefundBobr2 =
        generateNonce(alicePriv2, bobRefundTransaction2.id().data);
    final CurvePoint aliceRefundBobR2 = CurvePoint.fromScalar(aliceRefundBobr2);

    /// Alice signs [bobRefundTransaction2] and sends to Bob ----------------->.
    final JointKey aliceJointKey2 = JointKey.generate(
        <PublicKey>[alicePub2, PublicKey(bobRefundTransaction2.to.data)],
        alicePriv2,
        0);
    final SchnorrSignature bobRefundTransaction2signedByAlice = jointSign(
        alicePriv2,
        aliceJointKey2,
        <CurvePoint>[aliceRefundBobR2, bobRefundR2],
        bobRefundTransaction2.id().data);

    /// <--------------- Bob signs [aliceRefundTransaction1] and sends to Alice.
    final JointKey bobJointKey1 = JointKey.generate(
        <PublicKey>[PublicKey(aliceRefundTransaction1.to.data), bobPub1],
        bobPriv1,
        1);
    final SchnorrSignature aliceRefundTransaction1signedByBob = jointSign(
        bobPriv1,
        bobJointKey1,
        <CurvePoint>[aliceRefundR1, bobRefundAliceR1],
        aliceRefundTransaction1.id().data);

    /// Alice verifies [aliceRefundTransaction1]
    final SchnorrSignature aliceRefundTransaction1signedByAlice = jointSign(
        alicePriv1,
        aliceJointKey1,
        <CurvePoint>[aliceRefundR1, bobRefundAliceR1],
        aliceRefundTransaction1.id().data);
    final SchnorrSignature aliceRefundTransactionSignature = addSignatures(
        aliceRefundTransaction1signedByAlice,
        aliceRefundTransaction1signedByBob);
    aliceRefundTransaction1.signature =
        CruzSignature(aliceRefundTransactionSignature.data);
    expect(aliceRefundTransaction1.verify(), true);

    /// Bob verifies [bobRefundTransaction2]
    final SchnorrSignature bobRefundTransaction2signedByBob = jointSign(
        bobPriv2,
        bobJointKey2,
        <CurvePoint>[aliceRefundBobR2, bobRefundR2],
        bobRefundTransaction2.id().data);
    final SchnorrSignature bobRefundTransactionSignature = addSignatures(
        bobRefundTransaction2signedByAlice, bobRefundTransaction2signedByBob);
    bobRefundTransaction2.signature =
        CruzSignature(bobRefundTransactionSignature.data);
    expect(bobRefundTransaction2.verify(), true);

    /// Alice brodcasts [aliceFundingTransaction1] to the cruz1 [PeerNetwork].

    /// Bob brodcasts [bobFundingTransaction2] to the cruz2 [PeerNetwork].

    /// <----------------------------------- Bob sends Alice [bobAdaptor.point].
    final Adaptor bobAdaptor = Adaptor.generate(randBytes(32));

    /// <-------------------- Bob sends Alice [bobAdaptorSignatureForBobsClaim].
    final bobClaimr1 = generateNonce(bobPriv1, bobClaimTransaction1.id().data);
    final CurvePoint bobClaimR1 = CurvePoint.fromScalar(bobClaimr1);
    final SchnorrSignature bobAdaptorSignatureForBobsClaim =
        jointSignWithAdaptor(bobPriv1, bobJointKey1, aliceBobClaimR1,
            bobClaimR1, bobAdaptor.point, bobClaimTransaction1.id().data);
    expect(equalUint8List(bobAdaptorSignatureForBobsClaim.R, bobClaimR1.pack()),
        true);

    /// <------------------ Bob sends Alice [bobAdaptorSignatureForAlicesClaim].
    final SchnorrSignature bobAdaptorSignatureForAlicesClaim =
        jointSignWithAdaptor(
            bobPriv2,
            bobJointKey2,
            aliceClaimR2,
            bobAliceClaimR2,
            bobAdaptor.point,
            aliceClaimTransaction2.id().data);
    expect(
        equalUint8List(
            bobAdaptorSignatureForAlicesClaim.R, bobAliceClaimR2.pack()),
        true);

    /// Alice verifies [bobAdaptorSignatureForBobsClaim].
    expect(
        verifyAdaptorSignature(
            aliceJointKey1.primePublicKeys[1],
            aliceJointKey1.jointPublicKey,
            aliceBobClaimR1,
            CurvePoint.unpack(bobAdaptorSignatureForBobsClaim.R),
            bobAdaptor.point,
            bobClaimTransaction1.id().data,
            bobAdaptorSignatureForBobsClaim),
        true);

    /// Alice verifies [bobAdaptorSignatureForAlicesClaim].
    expect(
        verifyAdaptorSignature(
            aliceJointKey2.primePublicKeys[1],
            aliceJointKey2.jointPublicKey,
            aliceClaimR2,
            CurvePoint.unpack(bobAdaptorSignatureForAlicesClaim.R),
            bobAdaptor.point,
            aliceClaimTransaction2.id().data,
            bobAdaptorSignatureForAlicesClaim),
        true);

    /// Alice sends Bob [aliceAdaptorSignatureForBobsClaim].
    final SchnorrSignature aliceAdaptorSignatureForBobsClaim =
        jointSignWithAdaptor(
            alicePriv1,
            aliceJointKey1,
            aliceBobClaimR1,
            CurvePoint.unpack(bobAdaptorSignatureForBobsClaim.R),
            bobAdaptor.point,
            bobClaimTransaction1.id().data);
    expect(
        equalUint8List(
            aliceAdaptorSignatureForBobsClaim.R, aliceBobClaimR1.pack()),
        true);

    /// Bob signs and broadcasts [bobClaimTransaction1] to the cruz1 [PeerNetwork].
    final SchnorrSignature bobClaimSignature = addSignatures(
        addSignatures(
            aliceAdaptorSignatureForBobsClaim, bobAdaptorSignatureForBobsClaim),
        SchnorrSignature(bobAdaptor.point.pack(), bobAdaptor.secret));
    bobClaimTransaction1.signature = CruzSignature(bobClaimSignature.data);
    expect(bobClaimTransaction1.verify(), true);

    /// Alice deduces [bobAdaptor.secret].
    final Uint8List secret = CurvePoint.subtractScalars(
        bobClaimTransaction1.signature.data.sublist(32),
        CurvePoint.addScalars(aliceAdaptorSignatureForBobsClaim.s,
            bobAdaptorSignatureForBobsClaim.s));
    expect(equalUint8List(secret, bobAdaptor.secret), true);

    /// Alice signs and broadcasts [aliceClaimTransaction2] to the cruz2 [PeerNetwork].
    final SchnorrSignature aliceAdaptorSignatureForAlicesClaim =
        jointSignWithAdaptor(
            alicePriv2,
            aliceJointKey2,
            aliceClaimR2,
            bobAliceClaimR2,
            bobAdaptor.point,
            aliceClaimTransaction2.id().data);
    expect(
        equalUint8List(
            aliceAdaptorSignatureForAlicesClaim.R, aliceClaimR2.pack()),
        true);
    final SchnorrSignature aliceClaimSignature = addSignatures(
        addSignatures(aliceAdaptorSignatureForAlicesClaim,
            bobAdaptorSignatureForAlicesClaim),
        SchnorrSignature(bobAdaptor.point.pack(), secret));
    aliceClaimTransaction2.signature = CruzSignature(aliceClaimSignature.data);
    expect(aliceClaimTransaction2.verify(), true);
  });
}
