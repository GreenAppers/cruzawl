// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'btc_test.dart' as btc_test;
import 'cruz_test.dart' as cruz_test;
import 'eth_test.dart' as eth_test;
import 'sembast_test.dart' as sembast_test;
import 'wallet_test.dart' as wallet_test;

void main() {
  group('btc', btc_test.main);
  group('cruz', cruz_test.main);
  group('eth', eth_test.main);
  group('sembast', sembast_test.main);
  group('wallet', wallet_test.main);
}
