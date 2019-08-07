import 'package:test/test.dart';

import 'package:cruzawl/test.dart';

void main() {
  CruzTester(group, test, expect).run();
  WalletTester(group, test, expect).run();
}
