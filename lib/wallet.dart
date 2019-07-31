// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart';
import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sembast/sembast.dart' as sembast;

import 'package:cruzawl/currency.dart';
import 'package:cruzawl/network.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/sembast.dart';
import 'package:cruzawl/util.dart';

part 'wallet.g.dart';

/// BIP44 account
@JsonSerializable(includeIfNull: false)
class Account {
  int id, nextIndex = 0;

  @JsonKey(ignore: true)
  double balance = 0;

  @JsonKey(ignore: true)
  double maturesBalance = 0;

  @JsonKey(ignore: true)
  int maturesHeight = 0;

  @JsonKey(ignore: true)
  SplayTreeMap<int, Address> reserveAddress = SplayTreeMap<int, Address>();

  Account(this.id);

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);
}

/// SLIP-0010 seed
class Seed {
  final Uint8List data;
  static const int size = 64;

  Seed(this.data) {
    assert(data.length == size);
  }

  Seed.fromJson(String x) : this(base64.decode(x));

  String toJson() => base64.encode(data);
}

typedef WalletCallback = void Function(Wallet);

abstract class WalletStorage {
  String name, seedPhrase;
  Seed seed;
  Currency currency;
  sembast.Database storage;
  var walletStore, accountStore, addressStore, pendingStore;
  Map<int, Account> accounts = <int, Account>{0: Account(0)};
  Map<String, Address> addresses = <String, Address>{};
  int pendingCount = 0;
  num balance = 0;

  WalletStorage(this.name, this.currency, this.seed, [this.seedPhrase]);

  Account addAccount(Account x, {bool store = true});
  Address addAddress(Address x,
      {bool store = true, bool load = true, sembast.Transaction txn});
  void updateTransaction(Transaction transaction,
      {bool newTransaction = true});

  Future<void> storeHeader() async {
    await walletStore.record('header').put(
        storage,
        jsonDecode(jsonEncode(<String, dynamic>{
          'name': name,
          'seed': seed,
          'seedPhrase': seedPhrase,
          'currency': currency,
        })));
  }

  Future<void> readStoredHeader() async {
    var header = await walletStore.record('header').get(storage);
    name = header['name'] as String;
    seed = Seed.fromJson(header['seed']);
    seedPhrase = header['seedPhrase'] as String;
    currency = Currency.fromJson(header['currency']);
  }

  Future<void> storeAccount(Account x, [sembast.Transaction txn]) async {
    await accountStore.record(x.id).put(txn ?? storage, x.toJson());
  }

  Future<void> readStoredAccounts() async {
    var finder = sembast.Finder(sortOrders: [sembast.SortOrder('id')]);
    var records = await accountStore.find(storage, finder: finder);
    for (var record in records)
      addAccount(Account.fromJson(record.value), store: false);
  }

  Future<void> storeAddress(Address x, [sembast.Transaction txn]) async {
    await addressStore
        .record(x.publicKey.toJson())
        .put(txn ?? storage, jsonDecode(jsonEncode(x)));
  }

  Future<void> readStoredAddresses({bool load = true}) async {
    var finder = sembast.Finder(sortOrders: [sembast.SortOrder('id')]);
    var records = await addressStore.find(storage, finder: finder);
    for (var record in records) {
      Address x = addAddress(currency.fromAddressJson(record.value),
          store: false, load: load);
      accounts[x.accountId].balance += x.balance;
      balance += x.balance;
    }
  }

  Future<void> removePendingTransaction(String id) async =>
      pendingStore.record(id).delete(storage);

  Future<void> storePendingTransaction(Transaction tx) async {
    String id = tx.id().toJson();
    await pendingStore.record(id).put(storage, jsonDecode(jsonEncode(tx)));
  }

  Future<void> readPendingTransactions() async {
    var finder = sembast.Finder(sortOrders: [sembast.SortOrder('id')]);
    var records = await pendingStore.find(storage, finder: finder);
    for (var record in records) {
      updateTransaction(currency.fromTransactionJson(record.value),
          newTransaction: false);
      pendingCount++;
    }
  }
}

class Wallet extends WalletStorage {
  num maturesBalance = 0;
  int activeAccountId = 0,
      maturesHeight = 0,
      nextAddressIndex;
  PriorityQueue<Transaction> maturing =
      PriorityQueue<Transaction>(Transaction.maturityCompare);
  SortedListSet<Transaction> transactions =
      SortedListSet<Transaction>(Transaction.timeCompare, List<Transaction>());
  Map<String, Transaction> transactionIds = Map<String, Transaction>();
  VoidCallback notifyListeners, balanceChanged;
  ErrorDetails fatal;
  StringCallback debugPrint;
  CruzawlPreferences preferences;

  /// Generate new HD [Wallet]
  Wallet.generate(sembast.DatabaseFactory databaseFactory, String filename,
      String name, Currency currency,
      [CruzawlPreferences prefs, StringCallback debug, WalletCallback loaded])
      : this.fromSeedPhrase(databaseFactory, filename, name, currency,
            generateMnemonic(), prefs, debug, loaded);

  /// Generate HD [Wallet] from BIP-0039 mnemonic code
  Wallet.fromSeedPhrase(sembast.DatabaseFactory databaseFactory,
      String filename, String name, Currency currency, String seedPhrase,
      [CruzawlPreferences prefs, StringCallback debug, WalletCallback loaded])
      : this.fromSeed(databaseFactory, filename, name, currency,
            Seed(mnemonicToSeed(seedPhrase)), seedPhrase, prefs, debug, loaded);

  /// Generate HD [Wallet] from SLIP-0010 seed
  Wallet.fromSeed(sembast.DatabaseFactory databaseFactory, String filename,
      String name, Currency currency, Seed seed,
      [String seedPhrase,
      this.preferences,
      this.debugPrint,
      WalletCallback loaded])
      : super(name, currency, seed, seedPhrase) {
    if (filename != null)
      openWalletStorage(databaseFactory, filename, true, loaded);
  }

  /// Create non-HD [Wallet] from private key list
  Wallet.fromPrivateKeyList(
      sembast.DatabaseFactory databaseFactory,
      String filename,
      String name,
      Currency currency,
      Seed seed,
      List<PrivateKey> privateKeys,
      [this.preferences,
      this.debugPrint,
      WalletCallback loaded])
      : super(name, currency, seed) {
    if (filename != null)
      openWalletStorage(databaseFactory, filename, true, loaded, privateKeys);
  }

  /// Create watch-only [Wallet] from public key list
  Wallet.fromPublicKeyList(
      sembast.DatabaseFactory databaseFactory,
      String filename,
      String name,
      Currency currency,
      Seed seed,
      List<PublicAddress> publicKeys,
      [this.preferences,
      this.debugPrint,
      WalletCallback loaded])
      : super(name, currency, seed) {
    if (filename != null)
      openWalletStorage(
          databaseFactory, filename, true, loaded, null, publicKeys);
  }

  Wallet.fromFile(
      sembast.DatabaseFactory databaseFactory, String filename, Seed seed,
      [this.preferences, this.debugPrint, WalletCallback loaded])
      : super('loading', const LoadingCurrency(), seed) {
    openWalletStorage(databaseFactory, filename, false, loaded);
  }

  bool get hdWallet => seedPhrase != null;

  Account get account => accounts[activeAccountId];

  Address getNextAddress() {
    if (hdWallet) {
      if (account.reserveAddress.length > 0)
        return account.reserveAddress.entries.first.value;
      else
        return addNextAddress();
    } else {
      if (addresses.length <= 0) return null;
      nextAddressIndex = ((nextAddressIndex ?? -1) + 1) % addresses.length;
      return addresses.values.toList()[nextAddressIndex];
    }
  }

  String bip44Path(int index, int coinType,
      {int bip43Purpose = 44, int accountId = 0, int change = 0}) {
    return "m/$bip43Purpose'/$coinType'/$accountId'/$change'/$index'";
  }

  Address deriveAddressWithPath(String path) =>
      currency.deriveAddress(seed.data, path, debugPrint);

  Address deriveAddress(int index, {int accountId = 0, int change = 0}) =>
      deriveAddressWithPath(bip44Path(index, currency.bip44CoinType,
          accountId: accountId, change: change))
        ..accountId = accountId
        ..chainIndex = index;

  Address addNextAddress(
      {bool load = true, Account account, sembast.Transaction txn}) {
    if (!hdWallet) return null;
    if (account == null) account = this.account;
    return addAddress(deriveAddress(account.nextIndex, accountId: account.id),
        load: load, txn: txn);
  }

  /// Store address & filter for it
  Address addAddress(Address x,
      {bool store = true, bool load = true, sembast.Transaction txn}) {
    if (preferences != null &&
        preferences.verifyAddressEveryLoad &&
        !x.verify())
      throw FormatException('${x.publicKey.toJson()} verify failed');
    addresses[x.publicKey.toJson()] = x;
    if (store) storeAddress(x, txn);
    if (load) filterNetworkFor(x);
    if (x.chainIndex != null) {
      if (x.state == AddressState.reserve)
        account.reserveAddress[x.chainIndex] = x;
      if (x.chainIndex >= account.nextIndex) {
        account.nextIndex = x.chainIndex + 1;
        storeAccount(account, txn);
      }
    } else {
      x.accountId = 0;
      x.state = AddressState.used;
    }
    return x;
  }

  Account addAccount(Account x, {bool store = true}) {
    accounts[x.id] = x;
    activeAccountId = x.id;
    if (store) storeAccount(x);
    return x;
  }

  Future<void> openWalletStorage(
      sembast.DatabaseFactory databaseFactory, String filename, bool create,
      [WalletCallback opened,
      List<PrivateKey> privateKeys,
      List<PublicAddress> publicKeys]) async {
    bool testing = preferences != null && preferences.testing;
    try {
      debugPrint((create ? 'Creating' : 'Opening') + ' wallet $filename ...');
      if (create && !testing && await File(filename).exists())
        throw FileSystemException('$filename already exists');
      storage = await databaseFactory.openDatabase(filename,
          codec: getSalsa20SembastCodec(
              Uint8List.fromList(seed.data.sublist(32))));
      walletStore = sembast.StoreRef<String, dynamic>.main();
      accountStore = sembast.intMapStoreFactory.store('accounts');
      addressStore = sembast.stringMapStoreFactory.store('addresses');
      pendingStore = sembast.stringMapStoreFactory.store('pendingTransactions');

      if (create) {
        await storeHeader();
        await storeAccount(account);
      } else {
        await readStoredHeader();
        await readStoredAccounts();
        await readStoredAddresses(load: false);
      }
    } catch (error, stackTrace) {
      fatal = ErrorDetails(exception: error, stack: stackTrace);
      if (opened != null)
        return opened(this);
      else
        rethrow;
    }

    if (hdWallet) {
      for (Account account in accounts.values)
        while (account.reserveAddress.length <
            (preferences.minimumReserveAddress ?? 5)) {
          addNextAddress(account: account, load: false);
          await Future.delayed(Duration(seconds: 0));
        }
    } else if (privateKeys != null) {
      if (privateKeys.length <= 0) return;
      for (PrivateKey key in privateKeys) {
        addAddress(currency.fromPrivateKey(key), load: false);
        await Future.delayed(Duration(seconds: 0));
      }
    } else if (publicKeys != null) {
      if (publicKeys.length <= 0) return;
      for (PublicAddress key in publicKeys) {
        addAddress(currency.fromPublicKey(key), load: false);
        await Future.delayed(Duration(seconds: 0));
      }
    }

    if (opened != null) opened(this);
    if (notifyListeners != null) notifyListeners();
    reload();
  }

  void expirePendingTransactions(int height) async {
    var finder = sembast.Finder(
      filter: sembast.Filter.lessThan('expires', height),
      sortOrders: [sembast.SortOrder('expires')],
    );
    var records = await pendingStore.find(storage, finder: finder);
    for (var record in records) {
      Transaction transaction =
          transactions.find(currency.fromTransactionJson(record.value));
      if (transaction != null &&
          (transaction.height == null || transaction.height == 0))
        updateBalance(addresses[transaction.from.toJson()],
            transaction.amount + transaction.fee);
      removePendingTransaction(record.key);
      pendingCount--;
    }
  }

  void completeMaturingTransactions(int height) {
    while (maturing.length > 0 && maturing.first.maturity <= height) {
      Transaction transaction = maturing.removeFirst();
      Address to = addresses[transaction.to.toJson()];
      applyMaturesBalanceDelta(to, -transaction.amount);
      updateBalance(to, transaction.amount);
    }
  }

  void reload() async {
    pendingCount = 0;
    transactions.clear();
    readPendingTransactions();

    List<Address> reloadAddresses = addresses.values.toList();
    List<Future<void>> reloading = List<Future<void>>(reloadAddresses.length);
    for (int i = 0; i < reloadAddresses.length; i++)
      reloading[i] = filterNetworkFor(reloadAddresses[i]);
    for (int i = 0; i < reloadAddresses.length; i++) await reloading[i];

    if (currency.network.hasPeer)
      (await currency.network.getPeer()).filterTransactionQueue();
  }

  Future<void> filterNetworkFor(Address x) async {
    if (!currency.network.hasPeer) return voidResult();
    Peer peer = await currency.network.getPeer();
    if (peer == null) return voidResult();

    x.newBalance = x.newMaturesBalance = 0;
    bool filtering = await peer.filterAdd(x.publicKey, updateTransaction);
    if (filtering == null) return voidResult();
    assert(filtering == true);

    num newBalance = await peer.getBalance(x.publicKey);
    if (newBalance == null) return voidResult();

    x.loadedHeight = x.loadedIndex = null;
    x.newBalance += newBalance;
    do {
      // Load most recent 100 blocks worth of transactions
      if (await getNextTransactions(peer, x) == null) return voidResult();
    } while (
        x.loadedHeight > max(0, peer.tip.height - currency.coinbaseMaturity));

    /// [Address] [newBalance] and [newMatureBalance] account for possibly
    /// receiving new transactions for [x] as we're loading
    applyMaturesBalanceDelta(x, -x.maturesBalance + x.newMaturesBalance);
    updateBalance(x, -x.balance + x.newBalance);
    x.newBalance = x.newMaturesBalance = null;
    if (notifyListeners != null) notifyListeners();
  }

  Future<TransactionIteratorResults> getNextTransactions(
      Peer peer, Address x) async {
    if (x.loadedHeight != null) {
      if (x.loadedIndex == 0)
        x.loadedHeight--;
      else
        x.loadedIndex--;
    }
    TransactionIteratorResults results = await peer.getTransactions(
      x.publicKey,
      startHeight: x.loadedHeight,
      startIndex: x.loadedIndex,
      endHeight: x.loadedHeight != null ? 0 : null,
    );
    if (results == null) return null;
    for (Transaction transaction in results.transactions)
      updateTransaction(transaction, newTransaction: false);

    if (x.loadedHeight != null &&
        (results.height > x.loadedHeight ||
            (results.height == x.loadedHeight &&
                results.index > x.loadedIndex))) {
      x.loadedHeight = x.loadedIndex = 0;
    } else {
      x.loadedHeight = results.height;
      x.loadedIndex = results.index;
    }
    return results;
  }

  Future<Transaction> newTransaction(Transaction transaction) async {
    pendingCount++;
    await storePendingTransaction(transaction);
    return transaction;
  }

  void updateTransaction(Transaction transaction,
      {bool newTransaction = true}) {
    int height = transaction.height ?? 0;
    bool undo = height < 0, transactionsChanged;
    if (undo) {
      transactionsChanged = transactions.remove(transaction);
      transactionIds.remove(transaction.id().toJson());
    } else {
      transactionsChanged = transactions.add(transaction);
      transactionIds[transaction.id().toJson()] = transaction;
    }
    bool balanceChanged = transactionsChanged && (newTransaction || undo);
    bool mature = transaction.maturity <= currency.network.tipHeight;

    Address from =
        transaction.from == null ? null : addresses[transaction.from.toJson()];
    Address to = addresses[transaction.to.toJson()];
    if (from != null) {
      if (height > 0) from.updateSeenHeight(height);
      updateAddressState(from, AddressState.used, store: !balanceChanged);
    }
    if (to != null) {
      if (height > 0) to.updateSeenHeight(height);
      updateAddressState(to, AddressState.used, store: !balanceChanged);
    }

    if (balanceChanged) {
      if (from != null) {
        num cost = transaction.amount + transaction.fee;
        updateBalance(from, undo ? cost : -cost);
      }
      if (to != null && mature)
        updateBalance(to, undo ? -transaction.amount : transaction.amount);
    }

    if (to != null && !mature && transactionsChanged)
      applyMaturesBalanceDelta(
          to, undo ? -transaction.amount : transaction.amount, transaction);

    /*debugPrint('${transaction.fromText} -> ${transaction.toText} ' +
               currency.format(transaction.amount) +
               ' mature=$mature, changed=$balanceChanged');*/
  }

  void updateBalance(Address x, num delta) {
    if (x == null || delta == 0) return;
    applyBalanceDelta(x, delta);
    storeAddress(x);
    if (notifyListeners != null) notifyListeners();
    if (balanceChanged != null) balanceChanged();
  }

  void updateAddressState(Address x, AddressState newState,
      {bool store = true}) {
    if (x.state == newState) return;
    bool wasReserve = x.state == AddressState.reserve;
    if (wasReserve) accounts[x.accountId].reserveAddress.remove(x.chainIndex);
    x.state = newState;
    if (store) {
      storeAddress(x);
      if (notifyListeners != null) notifyListeners();
    }
    if (wasReserve) addNextAddress(account: accounts[x.accountId]);
  }

  void updateTip() {
    assert(currency.network.tipHeight != null);
    expirePendingTransactions(currency.network.tipHeight);
    completeMaturingTransactions(currency.network.tipHeight);
    if (notifyListeners != null) notifyListeners();
  }

  void applyBalanceDelta(Address x, num delta) {
    x.balance += delta;
    if (x.newBalance != null) x.newBalance += delta;
    accounts[x.accountId].balance += delta;
    balance += delta;
  }

  void applyMaturesBalanceDelta(Address x, num delta,
      [Transaction transaction]) {
    x.maturesBalance += delta;
    if (x.newMaturesBalance != null) x.newMaturesBalance += delta;
    Account account = accounts[x.accountId];
    account.maturesBalance += delta;
    maturesBalance += delta;

    if (transaction == null) return;
    int maturity = transaction.maturity;
    x.maturesHeight = max(x.maturesHeight, maturity);
    account.maturesHeight = max(account.maturesHeight, maturity);
    maturesHeight = max(maturesHeight, maturity);

    if (delta > 0)
      maturing.add(transaction);
    else
      maturing.remove(transaction);
  }
}
