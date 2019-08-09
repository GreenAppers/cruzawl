// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:cruzawl/http.dart';
import 'package:cruzawl/util.dart';

typedef ExchangeRatesCallback = void Function(ExchangeRates);

/// Container for [ExchangeRate].
class ExchangeRates {
  StringCallback debugPrint;
  ExchangeRatesCallback update;
  DateTime updated;
  Duration updateDuration;
  Map<String, ExchangeRate> data = Map<String, ExchangeRate>();

  ExchangeRates(
      {this.update = defaultExchangeRatesUpdate,
      this.updateDuration = const Duration(minutes: 1),
      this.debugPrint});

  /// Update [base] to [currency] exchange rate to [amount].
  ExchangeRate updateRate(String base, String currency, num amount) {
    ExchangeRate rate = data[base];
    if (rate == null) rate = data[base] = ExchangeRate(base);
    rate.to[currency] = amount;
    rate.updated = DateTime.now();
    debugPrint('Updated ${rate.from} -> $currency = $amount');
    return rate;
  }

  /// Calls [update] rate-limited to once per [updateDuration].
  void checkForUpdate() {
    DateTime now = DateTime.now();
    if (updated != null && now.isBefore(updated.add(updateDuration))) return;
    updated = now;
    update(this);
  }

  /// Converts [source] -> BTC -> [target].
  num rateViaBTC(String source, String target) {
    ExchangeRate sourceRate = data[source], btcRate = data['BTC'];
    if (sourceRate == null || btcRate == null) return 0;
    num toBtc = sourceRate.to['BTC'], toTarget = btcRate.to[target];
    if (toBtc == null || toTarget == null) return 0;
    return toBtc * toTarget;
  }
}

/// Collection of exchange rates: [ExchangeRate.from] -> [ExchangeRate.to].
class ExchangeRate {
  DateTime updated;
  String from;
  Map<String, num> to = Map<String, num>();
  ExchangeRate(this.from);
}

/// Updates BTC -> USD.
void updateBtc2UsdWithCoinbase(ExchangeRates rates) {
  /// {"data":{"base":"BTC","currency":"USD","amount":"11784.005"}}
  HttpRequest.request('https://api.coinbase.com/v2/prices/spot?currency=USD')
      .then((resp) {
    Map<String, dynamic> data = jsonDecode(resp.text)['data'];
    String base = data['base'], currency = data['currency'];
    assert(base == 'BTC');
    assert(currency == 'USD');
    rates.updateRate(base, currency, num.parse(data['amount']));
  });
}

/// Updates CRUZ -> BTC.
void updateCruzToBtcWithQtrade(ExchangeRates rates) {
  /// {"id":32,"market_currency":"CRUZ","base_currency":"BTC","maker_fee":"0","taker_fee":"0.015","metadata":{},"can_trade":true,"can_cancel":true,"can_view":true},
  /// Reference: https://api.qtrade.io/v1/markets
  int qtrade_cruz_market_id = 32;

  /// {"data":{"market":{"id":32,"market_currency":"CRUZ","base_currency":"BTC","maker_fee":"0","taker_fee":"0.015","metadata":{},"can_trade":true,"can_cancel":true,"can_view":false},"recent_trades":[{"id":55989,"amount":"6.70380253","price":"0.00001499","created_at":"2019-08-09T11:27:24.430434Z"}]}}
  HttpRequest.request('https://api.qtrade.io/v1/market/32').then((resp) {
    /// Unfortunately it is a bit complicated to change the CORS policy for just
    /// the public endpoints with the way our backend is setup, but it is on our
    /// list of improvements -Eric @ qTrade
    Map<String, dynamic> data = jsonDecode(resp.text)['data'];
    String base = data['market_currency'], currency = data['base_currency'];
    assert(base == 'CRUZ');
    assert(currency == 'BTC');
    rates.updateRate(base, currency, num.parse(data['recent_trades'][0]['price']));
  });
}

/// Updates CRUZ -> BTC.
void updateCruzToBtcWithVinex(ExchangeRates rates) {
  /// {"status":200,"data":{"id":4000027,"symbol":"BTC_CRUZ","assetId1":1,"assetId2":3000015,"lastPrice":0,"bidPrice":0,"askPrice":0,"volume":0,"weeklyVolume":0,"monthlyVolume":0,"volume24h":0,"asset2Volume24h":0,"change24h":0,"high24h":0,"low24h":0,"createdAt":1564564587,"updatedAt":1565380556,"status":true,"statusTrading":1,"threshold":0.001,"tradingFee":0.001,"makerFee":null,"takerFee":null,"decPrice":8,"decAmount":8,"totalVolume":0,"tokenInfo1":{"id":1,"name":"Bitcoin","symbol":"BTC"},"tokenInfo2":{"id":3000015,"name":"Cruzbit","symbol":"CRUZ"}}}
  HttpRequest.request('https://api.vinex.network/api/v2/markets/BTC_CRUZ').then((resp) {
    Map<String, dynamic> data = jsonDecode(resp.text)['data'];
    String base = data['tokenInfo2']['symbol'], currency = data['tokenInfo1']['symbol'];
    assert(base == 'CRUZ');
    assert(currency == 'BTC');
    rates.updateRate(base, currency, data['lastPrice']);
  });
}

/// Calls [updateBtc2UsdWithCoinbase()] and either [updateCurrenciesToBtcWithVinex] or
/// [updateCurrenciesToBtcWithQtrade].
void defaultExchangeRatesUpdate(ExchangeRates rates) {
  updateBtc2UsdWithCoinbase(rates);
  if (HttpRequest.type != 'io') {
    updateCruzToBtcWithVinex(rates);
  } else {
    updateCruzToBtcWithQtrade(rates);
  }
}
