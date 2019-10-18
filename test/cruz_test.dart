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
  /// See [CruzTester] and [CruzWalletTester] in lib/test.dart for the on-device unit tests.
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

    /// Alice generates [alicePriv1] for cruz1 and [alicePriv2] for cruz2.
    final PrivateKey alicePriv1 = PrivateKey.fromSeed(randBytes(32));
    final PrivateKey alicePriv2 = PrivateKey.fromSeed(randBytes(32));
    final PublicKey alicePub1 = alicePriv1.publicKey;
    final PublicKey alicePub2 = alicePriv2.publicKey;

    /// Alice sends Bob [alicePub2], H([aliceRefundR1]), H([aliceClaimR2]),
    /// H([aliceRefundBobR2]), and H([aliceBobClaimR1]) ---------------------->.
    final Uint8List aliceRefundr1 = generateNonce(alicePriv1, randBytes(32));
    final CurvePoint aliceRefundR1 = CurvePoint.fromScalar(aliceRefundr1);
    final aliceClaimr2 = generateNonce(alicePriv2, randBytes(32));
    final CurvePoint aliceClaimR2 = CurvePoint.fromScalar(aliceClaimr2);
    final aliceRefundBobr2 = generateNonce(alicePriv2, randBytes(32));
    final CurvePoint aliceRefundBobR2 = CurvePoint.fromScalar(aliceRefundBobr2);
    final Uint8List aliceBobClaimr1 = generateNonce(alicePriv1, randBytes(32));
    final CurvePoint aliceBobClaimR1 = CurvePoint.fromScalar(aliceBobClaimr1);

    /// Bob generates [bobPriv1] for cruz1, [bobPriv2] for cruz2, and [bobAdaptor].
    final PrivateKey bobPriv1 = PrivateKey.fromSeed(randBytes(32));
    final PrivateKey bobPriv2 = PrivateKey.fromSeed(randBytes(32));
    final PublicKey bobPub1 = bobPriv1.publicKey, bobPub2 = bobPriv2.publicKey;
    final Adaptor bobAdaptor = Adaptor.generate(randBytes(32));

    /// <--------- Bob sends Alice [bobPub1], H([bobRefundr2]), H([bobClaimR1]),
    /// H([bobRefundAliceR1]), H([bobAliceClaimR2]), and [bobAdaptor.point].
    final Uint8List bobRefundr2 = generateNonce(bobPriv2, randBytes(32));
    final CurvePoint bobRefundR2 = CurvePoint.fromScalar(bobRefundr2);
    final bobClaimr1 = generateNonce(bobPriv1, randBytes(32));
    final CurvePoint bobClaimR1 = CurvePoint.fromScalar(bobClaimr1);
    final bobRefundAlicer1 = generateNonce(bobPriv1, randBytes(32));
    final CurvePoint bobRefundAliceR1 = CurvePoint.fromScalar(bobRefundAlicer1);
    final Uint8List bobAliceClaimr2 = generateNonce(bobPriv2, randBytes(32));
    final CurvePoint bobAliceClaimR2 = CurvePoint.fromScalar(bobAliceClaimr2);

    /// Bob creates [bobJointKey2].
    final JointKey bobJointKey2 =
        JointKey.generate(<PublicKey>[alicePub2, bobPub2], bobPriv2, 1);

    /// Alice creates [aliceJointKey1].
    final JointKey aliceJointKey1 =
        JointKey.generate(<PublicKey>[alicePub1, bobPub1], alicePriv1, 0);

    /// Alice sends Bob [aliceRefundR1], [aliceClaimR2], [aliceRefundBobR2], and
    /// [aliceBobClaimR1] ---------------------------------------------------->.

    /// Alice sends Bob [aliceFundingTransaction1] --------------------------->.
    final CruzTransaction aliceFundingTransaction1 = CruzTransaction(
        CruzPublicKey(alicePub1.data),
        CruzPublicKey(aliceJointKey1.jointPublicKey.data),
        aliceSendsBobCruz1 + cruz1fee,
        cruz1fee,
        null,
        seriesForHeight: cruz1height);

    /// Alice sends Bob [aliceRefundTransaction1] ---------------------------->.
    final CruzTransaction aliceRefundTransaction1 = CruzTransaction(
        CruzPublicKey(aliceJointKey1.jointPublicKey.data),
        CruzPublicKey(alicePub1.data),
        aliceSendsBobCruz1,
        cruz1fee,
        null,
        seriesForHeight: cruz1height + oneDayInBlocks,
        matures: cruz1height + oneDayInBlocks);

    /// Alice sends Bob [bobClaimTransaction1] ------------------------------->.
    final CruzTransaction bobClaimTransaction1 = CruzTransaction(
        CruzPublicKey(aliceJointKey1.jointPublicKey.data),
        CruzPublicKey(bobPub1.data),
        aliceSendsBobCruz1,
        cruz1fee,
        null,
        seriesForHeight: cruz1height,
        expires: cruz1height + oneDayInBlocks);

    /// Bob verifies [aliceRefundR1], [aliceClaimR2], [aliceRefundBobR2], and
    /// [aliceBobClaimR1].

    /// <-------------------------- Bob sends Alice [bobRefundR2], [bobClaimR1],
    /// [bobRefundAliceR1], and [bobAliceClaimR2].

    /// <--------------------------- Bob sends Alice [bobFundingTransaction2].
    final CruzTransaction bobFundingTransaction2 = CruzTransaction(
        CruzPublicKey(bobPub2.data),
        CruzPublicKey(bobJointKey2.jointPublicKey.data),
        bobSendsAliceCruz2 + cruz2fee,
        cruz2fee,
        null,
        seriesForHeight: cruz2height);

    /// <------------ Bob sends Alice [bobRefundTransaction2].
    final CruzTransaction bobRefundTransaction2 = CruzTransaction(
        CruzPublicKey(bobJointKey2.jointPublicKey.data),
        CruzPublicKey(bobPub2.data),
        bobSendsAliceCruz2,
        cruz2fee,
        null,
        seriesForHeight: cruz2height + oneDayInBlocks * 2,
        matures: cruz2height + oneDayInBlocks * 2);

    /// <--------- Bob sends Alice [aliceClaimTransaction2].
    final CruzTransaction aliceClaimTransaction2 = CruzTransaction(
        CruzPublicKey(bobJointKey2.jointPublicKey.data),
        CruzPublicKey(alicePub2.data),
        bobSendsAliceCruz2,
        cruz2fee,
        null,
        seriesForHeight: cruz2height,
        expires: cruz2height + oneDayInBlocks * 2);

    /// Alice verifies [bobRefundR2], [bobClaimR1], [bobRefundAliceR1], and
    /// [bobAliceClaimR2].

    /// Alice signs [bobRefundTransaction2] and sends to Bob ----------------->.
    final JointKey aliceJointKey2 = JointKey.generate(
        <PublicKey>[alicePub2, PublicKey(bobRefundTransaction2.to.data)],
        alicePriv2,
        0);
    final SchnorrSignature bobRefundTransaction2signedByAlice = jointSign(
        alicePriv2,
        aliceJointKey2,
        <CurvePoint>[aliceRefundBobR2, bobRefundR2],
        aliceRefundBobr2,
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
        bobRefundAlicer1,
        aliceRefundTransaction1.id().data);

    /// Alice verifies [aliceRefundTransaction1].
    expect(aliceRefundTransaction1signedByBob.R, bobRefundAliceR1.pack());
    final SchnorrSignature aliceRefundTransaction1signedByAlice = jointSign(
        alicePriv1,
        aliceJointKey1,
        <CurvePoint>[aliceRefundR1, bobRefundAliceR1],
        aliceRefundr1,
        aliceRefundTransaction1.id().data);
    final SchnorrSignature aliceRefundTransactionSignature = addSignatures(
        aliceRefundTransaction1signedByAlice,
        aliceRefundTransaction1signedByBob);
    aliceRefundTransaction1.signature =
        CruzSignature(aliceRefundTransactionSignature.data);
    expect(aliceRefundTransaction1.verify(), true);

    /// Bob verifies [bobRefundTransaction2].
    expect(bobRefundTransaction2signedByAlice.R, aliceRefundBobR2.pack());
    final SchnorrSignature bobRefundTransaction2signedByBob = jointSign(
        bobPriv2,
        bobJointKey2,
        <CurvePoint>[aliceRefundBobR2, bobRefundR2],
        bobRefundr2,
        bobRefundTransaction2.id().data);
    final SchnorrSignature bobRefundTransactionSignature = addSignatures(
        bobRefundTransaction2signedByAlice, bobRefundTransaction2signedByBob);
    bobRefundTransaction2.signature =
        CruzSignature(bobRefundTransactionSignature.data);
    expect(bobRefundTransaction2.verify(), true);

    /// Alice brodcasts [aliceFundingTransaction1] to the cruz1 [PeerNetwork].

    /// Bob brodcasts [bobFundingTransaction2] to the cruz2 [PeerNetwork].

    /// <-------------------- Bob sends Alice [bobAdaptorSignatureForBobsClaim].
    final SchnorrSignature bobAdaptorSignatureForBobsClaim =
        jointSignWithAdaptor(
            bobPriv1,
            bobJointKey1,
            aliceBobClaimR1,
            bobClaimR1,
            bobAdaptor.point,
            bobClaimr1,
            bobClaimTransaction1.id().data);

    /// <------------------ Bob sends Alice [bobAdaptorSignatureForAlicesClaim].
    final SchnorrSignature bobAdaptorSignatureForAlicesClaim =
        jointSignWithAdaptor(
            bobPriv2,
            bobJointKey2,
            aliceClaimR2,
            bobAliceClaimR2,
            bobAdaptor.point,
            bobAliceClaimr2,
            aliceClaimTransaction2.id().data);

    /// Alice verifies [bobAdaptorSignatureForBobsClaim].
    expect(bobAdaptorSignatureForBobsClaim.R, bobClaimR1.pack());
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
    expect(bobAdaptorSignatureForAlicesClaim.R, bobAliceClaimR2.pack());
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
            aliceBobClaimr1,
            bobClaimTransaction1.id().data);

    /// Bob signs and broadcasts [bobClaimTransaction1] to the cruz1 [PeerNetwork].
    expect(aliceAdaptorSignatureForBobsClaim.R, aliceBobClaimR1.pack());
    final SchnorrSignature bobClaimSignature = addSignatures(
        addSignatures(
            aliceAdaptorSignatureForBobsClaim, bobAdaptorSignatureForBobsClaim),
        SchnorrSignature(bobAdaptor.point.pack(), bobAdaptor.secret));
    bobClaimTransaction1.signature = CruzSignature(bobClaimSignature.data);
    expect(bobClaimTransaction1.verify(), true);

    /// Alice deduces [bobAdaptor.secret] from [bobClaimTransaction1].
    final Uint8List secret = CurvePoint.subtractScalars(
        bobClaimTransaction1.signature.data.sublist(32),
        CurvePoint.addScalars(aliceAdaptorSignatureForBobsClaim.s,
            bobAdaptorSignatureForBobsClaim.s));
    expect(secret, bobAdaptor.secret);

    /// Alice signs and broadcasts [aliceClaimTransaction2] to the cruz2 [PeerNetwork].
    final SchnorrSignature aliceAdaptorSignatureForAlicesClaim =
        jointSignWithAdaptor(
            alicePriv2,
            aliceJointKey2,
            aliceClaimR2,
            bobAliceClaimR2,
            bobAdaptor.point,
            aliceClaimr2,
            aliceClaimTransaction2.id().data);
    expect(aliceAdaptorSignatureForAlicesClaim.R, aliceClaimR2.pack());
    final SchnorrSignature aliceClaimSignature = addSignatures(
        addSignatures(aliceAdaptorSignatureForAlicesClaim,
            bobAdaptorSignatureForAlicesClaim),
        SchnorrSignature(bobAdaptor.point.pack(), secret));
    aliceClaimTransaction2.signature = CruzSignature(aliceClaimSignature.data);
    expect(aliceClaimTransaction2.verify(), true);
  });

  /// For a Schnorr-Spilman[1] payment channel on CRUZ there's one hiccup:
  /// We need the atomicity of a single transaction conferring a balance to two
  /// parties on a ledger without multiple outputs per transaction.
  ///
  /// In general, those parties can form an ephemeral joint key, and jointly
  /// pre-sign transactions from it to each party forming it:
  ///   Transaction 1 from JointKey(A,B,C) -> A sending them 5 CRUZ,
  ///   Transaction 2 from JointKey(A,B,C) -> B sending them 9 CRUZ, and so on.
  /// Then a single transaction to JointKey(A,B,C) acts like a transaction with
  /// 3 outputs, albeit through an intermediate address and with an extra fee.
  ///
  /// The payment channel scheme described in [1] is updated as follows:
  ///   For each payment Alice and Bob form an ephemeral joint key as described.
  /// Now Alice must retain a return-balance transaction for each payment she
  /// makes until the channel is closed.
  ///
  /// References:
  /// [1] https://gist.github.com/markblundeberg/a3aba3c9d610e59c3c49199f697bc38b#schnorr-spilman-payment-channels-protocol
  test('cruz payment channel', () {
    /// One-way payment channel: Alice → Bob funded with [aliceFundsChannelWithCruz].
    num aliceFundsChannelWithCruz = cruz.parse('10');
    int cruzFee = cruz.parse(cruz.suggestedFee(null));
    int cruzTipHeight = 328328;
    int oneDayInBlocks = 6 * 24;

    /// Alice generates [alicePriv] to open the channel.
    final PrivateKey alicePriv = PrivateKey.fromSeed(randBytes(32));
    final PublicKey alicePub = alicePriv.publicKey;

    /// Alice sends Bob [alicePub], and H([aliceRefundR]) -------------------->.
    final Uint8List aliceRefundr = generateNonce(alicePriv, randBytes(32));
    final CurvePoint aliceRefundR = CurvePoint.fromScalar(aliceRefundr);

    /// Bob generates [bobPriv] to accept Alice's open channel request.
    final PrivateKey bobPriv = PrivateKey.fromSeed(randBytes(32));
    final PublicKey bobPub = bobPriv.publicKey;

    /// <------------------- Bob sends Alice [bobPub], and H([bobRefundAliceR]).
    final bobRefundAlicer = generateNonce(bobPriv, randBytes(32));
    final CurvePoint bobRefundAliceR = CurvePoint.fromScalar(bobRefundAlicer);

    /// Bob creates [bobJointKey].
    final JointKey bobJointKey =
        JointKey.generate(<PublicKey>[alicePub, bobPub], bobPriv, 1);

    /// Alice creates [aliceJointKey].
    final JointKey aliceJointKey =
        JointKey.generate(<PublicKey>[alicePub, bobPub], alicePriv, 0);
    expect(aliceJointKey.jointPublicKey.data, bobJointKey.jointPublicKey.data);

    /// Alice sends Bob [aliceFundingTransaction] ---------------------------->.
    final CruzTransaction aliceFundingTransaction = CruzTransaction(
        CruzPublicKey(alicePub.data),
        CruzPublicKey(aliceJointKey.jointPublicKey.data),
        aliceFundsChannelWithCruz + 3 * cruzFee,
        cruzFee,
        null,
        seriesForHeight: cruzTipHeight);

    /// Alice sends Bob [aliceRefundTransaction] and [aliceRefundR] ---------->.
    final CruzTransaction aliceRefundTransaction = CruzTransaction(
        CruzPublicKey(aliceJointKey.jointPublicKey.data),
        CruzPublicKey(alicePub.data),
        aliceFundsChannelWithCruz + 2 * cruzFee,
        cruzFee,
        null,
        seriesForHeight: cruzTipHeight + 3 * oneDayInBlocks,
        matures: cruzTipHeight + 3 * oneDayInBlocks);

    /// Bob verifies [aliceRefundR] and notes [aliceRefundTransaction.matures].

    /// <---------------- Bob signs [aliceRefundTransaction] and sends to Alice.
    final SchnorrSignature aliceRefundTransactionSignedByBob = jointSign(
        bobPriv,
        bobJointKey,
        <CurvePoint>[aliceRefundR, bobRefundAliceR],
        bobRefundAlicer,
        aliceRefundTransaction.id().data);

    /// Alice verifies [aliceRefundTransaction].
    expect(aliceRefundTransactionSignedByBob.R, bobRefundAliceR.pack());
    final SchnorrSignature aliceRefundTransactionSignedByAlice = jointSign(
        alicePriv,
        aliceJointKey,
        <CurvePoint>[aliceRefundR, bobRefundAliceR],
        aliceRefundr,
        aliceRefundTransaction.id().data);
    final SchnorrSignature aliceRefundTransactionSignature = addSignatures(
        aliceRefundTransactionSignedByAlice, aliceRefundTransactionSignedByBob);
    aliceRefundTransaction.signature =
        CruzSignature(aliceRefundTransactionSignature.data);
    expect(aliceRefundTransaction.verify(), true);

    /// Alice brodcasts [aliceFundingTransaction] to the cruz [PeerNetwork].

    /// Bob waits for confirmations then tells Alice that the channel is open.
    final int numChannelPayments = 5;
    final List<int> alicePaysBobCruzbits = <int>[444, 9099, 1233, 8778, 92201];
    final List<CruzTransaction> aliceReturnBalanceTransactions =
        <CruzTransaction>[];
    CruzTransaction lastBobReturnBalanceTransaction,
        lastBobCloseChannelTransaction;
    int aliceChannelBalance = aliceFundsChannelWithCruz, bobChannelBalance = 0;
    for (int i = 0; i < numChannelPayments; i++) {
      /// Alice generates ephemeral [alicePaymentPriv] to make her next payment.
      final PrivateKey alicePaymentPriv = PrivateKey.fromSeed(randBytes(32));
      final PublicKey alicePaymentPub = alicePaymentPriv.publicKey;

      /// Alice sends Bob [alicePaymentPub], H([aliceReturnBalanceR]),
      /// H([aliceBobReturnBalanceR]), and H([aliceBobCloseChannelR]) -------->.
      final Uint8List aliceReturnBalancer =
          generateNonce(alicePaymentPriv, randBytes(32));
      final CurvePoint aliceReturnBalanceR =
          CurvePoint.fromScalar(aliceReturnBalancer);
      final Uint8List aliceBobReturnBalancer =
          generateNonce(alicePaymentPriv, randBytes(32));
      final CurvePoint aliceBobReturnBalanceR =
          CurvePoint.fromScalar(aliceBobReturnBalancer);
      final Uint8List aliceBobCloseChannelr =
          generateNonce(alicePaymentPriv, randBytes(32));
      final CurvePoint aliceBobCloseChannelR =
          CurvePoint.fromScalar(aliceBobCloseChannelr);

      /// Bob generates [bobPaymentPriv] to accept Alice's next payment.
      final PrivateKey bobPaymentPriv = PrivateKey.fromSeed(randBytes(32));
      final PublicKey bobPaymentPub = bobPaymentPriv.publicKey;

      /// <------------ Bob sends Alice [bobPaymentPub], H([bobReturnBalanceR]),
      /// H([bobAliceReturnBalanceR]), and H([bobCloseChannelR]).
      final Uint8List bobReturnBalancer =
          generateNonce(bobPaymentPriv, randBytes(32));
      final CurvePoint bobReturnBalanceR =
          CurvePoint.fromScalar(bobReturnBalancer);
      final Uint8List bobAliceReturnBalancer =
          generateNonce(bobPaymentPriv, randBytes(32));
      final CurvePoint bobAliceReturnBalanceR =
          CurvePoint.fromScalar(bobAliceReturnBalancer);
      final Uint8List bobCloseChannelr =
          generateNonce(bobPaymentPriv, randBytes(32));
      final CurvePoint bobCloseChannelR =
          CurvePoint.fromScalar(bobCloseChannelr);

      /// Bob creates [bobPaymentJointKey].
      final JointKey bobPaymentJointKey = JointKey.generate(
          <PublicKey>[alicePaymentPub, bobPaymentPub], bobPaymentPriv, 1);

      /// Alice creates [alicePaymentJointKey].
      final JointKey alicePaymentJointKey = JointKey.generate(
          <PublicKey>[alicePaymentPub, bobPaymentPub], alicePaymentPriv, 0);
      expect(alicePaymentJointKey.jointPublicKey.data,
          bobPaymentJointKey.jointPublicKey.data);

      /// Alice sends Bob [aliceReturnBalanceR], [aliceBobReturnBalanceR],
      /// and [aliceBobCloseChannelR] ---------------------------------------->.

      /// Bob verifies [aliceReturnBalanceR], [aliceBobReturnBalanceR], and
      /// [aliceBobCloseChannelR].

      /// <-------------------------------- Bob sends Alice [bobReturnBalanceR],
      /// [bobAliceReturnBalanceR], and [bobCloseChannelR].

      /// Alice sends Bob signed [bobReturnBalanceTransaction] --------------->.
      final CruzTransaction bobReturnBalanceTransaction = CruzTransaction(
          CruzPublicKey(alicePaymentJointKey.jointPublicKey.data),
          CruzPublicKey(bobPub.data),
          bobChannelBalance + alicePaysBobCruzbits[i],
          cruzFee,
          null,
          seriesForHeight: cruzTipHeight);
      final SchnorrSignature bobReturnBalanceTransactionSignedByAlice =
          jointSign(
              alicePaymentPriv,
              alicePaymentJointKey,
              <CurvePoint>[aliceBobReturnBalanceR, bobReturnBalanceR],
              aliceBobReturnBalancer,
              bobReturnBalanceTransaction.id().data);

      /// Bob verifies [bobReturnBalanceTransaction].
      expect(bobReturnBalanceTransactionSignedByAlice.R,
          aliceBobReturnBalanceR.pack());
      final SchnorrSignature bobReturnBalanceTransactionSignedByByBob =
          jointSign(
              bobPaymentPriv,
              bobPaymentJointKey,
              <CurvePoint>[aliceBobReturnBalanceR, bobReturnBalanceR],
              bobReturnBalancer,
              bobReturnBalanceTransaction.id().data);
      final SchnorrSignature bobReturnBalanceTransactionSignature =
          addSignatures(bobReturnBalanceTransactionSignedByAlice,
              bobReturnBalanceTransactionSignedByByBob);
      bobReturnBalanceTransaction.signature =
          CruzSignature(bobReturnBalanceTransactionSignature.data);
      expect(bobReturnBalanceTransaction.verify(), true);

      /// <------------- Bob sends Alice signed [aliceReturnBalanceTransaction].
      final CruzTransaction aliceReturnBalanceTransaction = CruzTransaction(
          CruzPublicKey(bobPaymentJointKey.jointPublicKey.data),
          CruzPublicKey(alicePub.data),
          aliceChannelBalance - alicePaysBobCruzbits[i],
          cruzFee,
          null,
          seriesForHeight: cruzTipHeight);
      final SchnorrSignature aliceReturnBalanceTransactionSignedByBob =
          jointSign(
              bobPaymentPriv,
              bobPaymentJointKey,
              <CurvePoint>[aliceReturnBalanceR, bobAliceReturnBalanceR],
              bobAliceReturnBalancer,
              aliceReturnBalanceTransaction.id().data);

      /// Alice verifies [aliceReturnBalanceTransaction].
      expect(aliceReturnBalanceTransactionSignedByBob.R,
          bobAliceReturnBalanceR.pack());
      final SchnorrSignature aliceReturnBalanceTransactionSignedByByAlice =
          jointSign(
              alicePaymentPriv,
              alicePaymentJointKey,
              <CurvePoint>[aliceReturnBalanceR, bobAliceReturnBalanceR],
              aliceReturnBalancer,
              aliceReturnBalanceTransaction.id().data);
      final SchnorrSignature aliceReturnBalanceTransactionSignature =
          addSignatures(aliceReturnBalanceTransactionSignedByBob,
              aliceReturnBalanceTransactionSignedByByAlice);
      aliceReturnBalanceTransaction.signature =
          CruzSignature(aliceReturnBalanceTransactionSignature.data);
      expect(aliceReturnBalanceTransaction.verify(), true);

      /// Alice sends Bob signed [bobCloseChannelTransaction] ---------------->.
      final CruzTransaction bobCloseChannelTransaction = CruzTransaction(
          CruzPublicKey(aliceJointKey.jointPublicKey.data),
          CruzPublicKey(alicePaymentJointKey.jointPublicKey.data),
          aliceFundingTransaction.amount,
          cruzFee,
          null,
          seriesForHeight: cruzTipHeight);
      final SchnorrSignature bobCloseChannelTransactionSignedByAlice =
          jointSign(
              alicePriv,
              aliceJointKey,
              <CurvePoint>[aliceBobCloseChannelR, bobCloseChannelR],
              aliceBobCloseChannelr,
              bobCloseChannelTransaction.id().data);

      /// Bob verifies [bobCloseChannelTransaction].
      expect(bobCloseChannelTransactionSignedByAlice.R,
          aliceBobCloseChannelR.pack());
      final SchnorrSignature bobCloseChannelTransactionSignedByBob = jointSign(
          bobPriv,
          bobJointKey,
          <CurvePoint>[aliceBobCloseChannelR, bobCloseChannelR],
          bobCloseChannelr,
          bobCloseChannelTransaction.id().data);
      final SchnorrSignature bobCloseChannelTransactionSignature =
          addSignatures(bobCloseChannelTransactionSignedByAlice,
              bobCloseChannelTransactionSignedByBob);
      bobCloseChannelTransaction.signature =
          CruzSignature(bobCloseChannelTransactionSignature.data);
      expect(bobCloseChannelTransaction.verify(), true);

      /// Bob updates [bobChannelBalance], [lastBobCloseChannelTransaction],
      /// and [lastBobReturnBalanceTransaction].
      lastBobCloseChannelTransaction = bobCloseChannelTransaction;
      lastBobReturnBalanceTransaction = bobReturnBalanceTransaction;
      bobChannelBalance = bobReturnBalanceTransaction.amount;

      /// Alice updates [aliceChannelBalance], and stores [aliceReturnBalanceTransaction].
      aliceReturnBalanceTransactions.add(aliceReturnBalanceTransaction);
      aliceChannelBalance = aliceReturnBalanceTransaction.amount;
    }

    /// Bob broadcasts [lastBobCloseChannelTransaction] before [aliceRefundTransaction.matures].

    /// Bob waits for confirmation and then broadcasts [lastBobReturnBalanceTransaction].

    /// Alice broadcasts the matching transaction from [aliceReturnBalanceTransactions].

    /// The channel is closed.
    int sumAlicePaysBobCruzbits = alicePaysBobCruzbits.reduce((a, b) => a + b);
    expect(lastBobReturnBalanceTransaction.amount, sumAlicePaysBobCruzbits);
    expect(aliceReturnBalanceTransactions.last.amount,
        aliceFundsChannelWithCruz - sumAlicePaysBobCruzbits);
  });
}
