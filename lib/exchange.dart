// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:cruzawl/http.dart';
import 'package:cruzawl/preferences.dart';
import 'package:cruzawl/util.dart';

typedef ExchangeRatesCallback = void Function(ExchangeRates);

/// Container for [ExchangeRate].
class ExchangeRates {
  HttpClient httpClient;
  CruzawlPreferences preferences;
  StringCallback debugPrint;
  ExchangeRatesCallback update;
  DateTime updated;
  Duration updateDuration;
  Map<String, ExchangeRate> data = Map<String, ExchangeRate>();

  ExchangeRates(this.httpClient, this.preferences,
      {this.update = defaultExchangeRatesUpdate,
      this.updateDuration = const Duration(minutes: 10),
      this.debugPrint});

  /// Called before requesting updated [base] → [currency].
  ExchangeRate prepareUpdateRate(String base, String currency,
      {bool rateLimit = false}) {
    ExchangeRate rate = data[base];
    if (rate == null) rate = data[base] = ExchangeRate(base);
    if (rate.to[currency] == null) {
      rate.to[currency] = ExchangeRateTo(null);
    } else {
      ExchangeRateTo rateTo = rate.to[currency];
      DateTime now = DateTime.now();
      if (rateLimit && now.isBefore(rateTo.updated.add(updateDuration)))
        return null;
      rateTo.updated = now;
    }
    return rate;
  }

  /// Update [base] → [currency] exchange rate to [amount].
  ExchangeRate updateRate(String base, String currency, num amount,
      [String via]) {
    ExchangeRate rate = data[base];
    rate.to[currency].value = amount;
    debugPrint('Updated ${rate.from} -> $currency = $amount' +
        (via != null ? '(via $via)' : ''));
    return rate;
  }

  /// Calls [update] rate-limited to once per [updateDuration].
  void checkForUpdate() {
    DateTime now = DateTime.now();
    if (updated != null && now.isBefore(updated.add(updateDuration))) return;
    updated = now;
    update(this);
  }

  /// Converts [source] → BTC → [target].
  num rateViaBTC(String source, String target) {
    ExchangeRate sourceRate = data[source], btcRate = data['BTC'];
    if (sourceRate == null || btcRate == null) return 0;
    ExchangeRateTo toBtc = sourceRate.to['BTC'], toTarget = btcRate.to[target];
    if (toBtc == null || toTarget == null) return 0;
    return (toBtc.value ?? 0) * (toTarget.value ?? 0);
  }
}

/// Single exchange rate [value] and [updated] timestamp
class ExchangeRateTo {
  num value;
  DateTime updated;
  ExchangeRateTo(this.value) : updated = DateTime.now();
}

/// Collection of exchange rates: [ExchangeRate.from] → [ExchangeRate.to].
class ExchangeRate {
  String from;
  Map<String, ExchangeRateTo> to = Map<String, ExchangeRateTo>();
  ExchangeRate(this.from);
}

/// Updates BTC → [currency].
void updateBtcToCurrencyWithCoinbase(String currencyCode, ExchangeRates rates,
    {bool rateLimit = false}) {
  if (rates.prepareUpdateRate('BTC', currencyCode, rateLimit: rateLimit) ==
      null) return;

  /// {"data":{"base":"BTC","currency":"USD","amount":"11784.005"}}
  rates.httpClient
      .request('https://api.coinbase.com/v2/prices/spot?currency=$currencyCode')
      .then((resp) {
    Map<String, dynamic> data = jsonDecode(resp.text)['data'];
    String base = data['base'], currency = data['currency'];
    assert(base == 'BTC');
    assert(currency == currencyCode);
    rates.updateRate(base, currency, num.parse(data['amount']), 'Coinbase');
  });
}

/// Updates CRUZ → BTC.
void updateCruzToBtcWithQtrade(ExchangeRates rates, {bool rateLimit = false}) {
  if (rates.prepareUpdateRate('CRUZ', 'BTC', rateLimit: rateLimit) == null)
    return;

  /// {"id":32,"market_currency":"CRUZ","base_currency":"BTC","maker_fee":"0","taker_fee":"0.015","metadata":{},"can_trade":true,"can_cancel":true,"can_view":true},
  /// Reference: https://api.qtrade.io/v1/markets
  int qtradeCruzMarketId = 32;

  /// {"data":{"market":{"id":32,"market_currency":"CRUZ","base_currency":"BTC","maker_fee":"0","taker_fee":"0.015","metadata":{},"can_trade":true,"can_cancel":true,"can_view":false},"recent_trades":[{"id":55989,"amount":"6.70380253","price":"0.00001499","created_at":"2019-08-09T11:27:24.430434Z"}]}}
  rates.httpClient
      .request('https://api.qtrade.io/v1/market/$qtradeCruzMarketId')
      .then((resp) {
    /// Unfortunately it is a bit complicated to change the CORS policy for just
    /// the public endpoints with the way our backend is setup, but it is on our
    /// list of improvements -Eric @ qTrade
    Map<String, dynamic> data = jsonDecode(resp.text)['data'],
        market = data['market'];
    String base = market['market_currency'], currency = market['base_currency'];
    assert(base == 'CRUZ');
    assert(currency == 'BTC');
    rates.updateRate(
        base, currency, num.parse(data['recent_trades'][0]['price']), 'qTrade');
  });
}

/// Updates CRUZ → BTC.
void updateCruzToBtcWithVinex(ExchangeRates rates, {bool rateLimit = false}) {
  if (rates.prepareUpdateRate('CRUZ', 'BTC', rateLimit: rateLimit) == null)
    return;

  /// {"status":200,"data":{"id":4000027,"symbol":"BTC_CRUZ","assetId1":1,"assetId2":3000015,"lastPrice":0,"bidPrice":0,"askPrice":0,"volume":0,"weeklyVolume":0,"monthlyVolume":0,"volume24h":0,"asset2Volume24h":0,"change24h":0,"high24h":0,"low24h":0,"createdAt":1564564587,"updatedAt":1565380556,"status":true,"statusTrading":1,"threshold":0.001,"tradingFee":0.001,"makerFee":null,"takerFee":null,"decPrice":8,"decAmount":8,"totalVolume":0,"tokenInfo1":{"id":1,"name":"Bitcoin","symbol":"BTC"},"tokenInfo2":{"id":3000015,"name":"Cruzbit","symbol":"CRUZ"}}}
  rates.httpClient
      .request('https://api.vinex.network/api/v2/markets/BTC_CRUZ')
      .then((resp) {
    Map<String, dynamic> data = jsonDecode(resp.text)['data'];
    String base = data['tokenInfo2']['symbol'],
        currency = data['tokenInfo1']['symbol'];
    assert(base == 'CRUZ');
    assert(currency == 'BTC');
    rates.updateRate(base, currency, data['lastPrice'], 'Vinex');
  });
}

/// Calls [updateBtcToUsdWithCoinbase()] with rate-limiting.
void defaultUpdateBtcToCurrency(ExchangeRates rates) {
  updateBtcToCurrencyWithCoinbase(rates.preferences.localCurrency, rates,
      rateLimit: true);
}

/// Calls [updateBtcToUsdWithCoinbase()] and [updateCurrenciesToBtcWithQtrade].
void defaultExchangeRatesUpdate(ExchangeRates rates) {
  updateBtcToCurrencyWithCoinbase(rates.preferences.localCurrency, rates);
  updateCruzToBtcWithQtrade(rates);
}

/// http://api.coinbase.com/v2/currencies
List<String> coinbaseCurrencies = const <String>[
  'AED',
  'AFN',
  'ALL',
  'AMD',
  'ANG',
  'AOA',
  'ARS',
  'AUD',
  'AWG',
  'AZN',
  'BAM',
  'BBD',
  'BDT',
  'BGN',
  'BHD',
  'BIF',
  'BMD',
  'BND',
  'BOB',
  'BRL',
  'BSD',
  'BTN',
  'BWP',
  'BYN',
  'BYR',
  'BZD',
  'CAD',
  'CDF',
  'CHF',
  'CLF',
  'CLP',
  'CNH',
  'CNY',
  'COP',
  'CRC',
  'CUC',
  'CVE',
  'CZK',
  'DJF',
  'DKK',
  'DOP',
  'DZD',
  'EEK',
  'EGP',
  'ERN',
  'ETB',
  'EUR',
  'FJD',
  'FKP',
  'GBP',
  'GEL',
  'GGP',
  'GHS',
  'GIP',
  'GMD',
  'GNF',
  'GTQ',
  'GYD',
  'HKD',
  'HNL',
  'HRK',
  'HTG',
  'HUF',
  'IDR',
  'ILS',
  'IMP',
  'INR',
  'IQD',
  'ISK',
  'JEP',
  'JMD',
  'JOD',
  'JPY',
  'KES',
  'KGS',
  'KHR',
  'KMF',
  'KRW',
  'KWD',
  'KYD',
  'KZT',
  'LAK',
  'LBP',
  'LKR',
  'LRD',
  'LSL',
  'LTL',
  'LVL',
  'LYD',
  'MAD',
  'MDL',
  'MGA',
  'MKD',
  'MMK',
  'MNT',
  'MOP',
  'MRO',
  'MTL',
  'MUR',
  'MVR',
  'MWK',
  'MXN',
  'MYR',
  'MZN',
  'NAD',
  'NGN',
  'NIO',
  'NOK',
  'NPR',
  'NZD',
  'OMR',
  'PAB',
  'PEN',
  'PGK',
  'PHP',
  'PKR',
  'PLN',
  'PYG',
  'QAR',
  'RON',
  'RSD',
  'RUB',
  'RWF',
  'SAR',
  'SBD',
  'SCR',
  'SEK',
  'SGD',
  'SHP',
  'SLL',
  'SOS',
  'SRD',
  'SSP',
  'STD',
  'SVC',
  'SZL',
  'THB',
  'TJS',
  'TMT',
  'TND',
  'TOP',
  'TRY',
  'TTD',
  'TWD',
  'TZS',
  'UAH',
  'UGX',
  'USD',
  'UYU',
  'UZS',
  'VEF',
  'VES',
  'VND',
  'VUV',
  'WST',
  'XAF',
  'XAG',
  'XAU',
  'XCD',
  'XDR',
  'XOF',
  'XPD',
  'XPF',
  'XPT',
  'YER',
  'ZAR',
  'ZMK',
  'ZMW',
  'ZWL',
];
