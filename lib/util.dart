// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';

Future<void> voidResult() async {}

void checkEquals(String x, String y) {
  assert(x == y, '$x != $y');
}

bool equalUint8List(Uint8List x, Uint8List y) {
  if (x.length != y.length) return false;
  for (int i = 0; i < x.length; ++i) if (x[i] != y[i]) return false;
  return true;
}

Uint8List randBytes(int n) {
  final Random generator = Random.secure();
  final Uint8List random = Uint8List(n);
  for (int i = 0; i < random.length; i++) random[i] = generator.nextInt(255);
  return random;
}

class SortedListSet<T> {
  List<T> data;
  int Function(T, T) compare;
  SortedListSet(this.compare, this.data);

  int get length => data.length;

  void clear() => data.clear();

  bool add(T value) {
    int index = lowerBound(data, value, compare: compare);
    if (index < data.length && compare(data[index], value) == 0) {
      data[index] = value;
      return false;
    } else {
      data.insert(index, value);
      return true;
    }
  }

  bool remove(T value) {
    int index = binarySearch(data, value, compare: compare);
    if (index < 0) return false;
    data.removeAt(index);
    return true;
  }

  T find(T value) {
    int index = binarySearch(data, value, compare: compare);
    return index < 0 ? null : data[index];
  }
}
