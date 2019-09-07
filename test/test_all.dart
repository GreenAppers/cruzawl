// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'cruz_test.dart' as cruz_test;
import 'sembast_test.dart' as sembast_test;
import 'wallet_test.dart' as wallet_test;

void main() {
  group('cruz', cruz_test.main);
  group('sembast', sembast_test.main);
  group('wallet', wallet_test.main);
}
