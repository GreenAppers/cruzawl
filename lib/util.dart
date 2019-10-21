// Copyright 2019 cruzawl developers
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';

const int debugLevelError = 0;
const int debugLevelInfo = 1;
const int debugLevelDebug = 2;

typedef VoidCallback = void Function();
typedef StringCallback = void Function(String);
typedef StringFilter = String Function(String);
typedef StringFunction = String Function();
typedef StringFutureFunction = Future<String> Function();

Future<void> voidResult() async {}

/// Interface for dart:io [File].
abstract class FileSystem {
  Future<bool> exists(String filename);
  Future<void> remove(String filename);
}

/// Shim [FileSystem] for tests.
class NullFileSystem extends FileSystem {
  Future<bool> exists(String filename) async => false;
  Future<void> remove(String filename) async => voidResult();
}

/// Optionally [debugPrint] failed assertions in-app.
bool checkEquals(dynamic x, dynamic y, [StringCallback debugPrint]) {
  bool equals = x == y;
  if (debugPrint != null && !equals) debugPrint('assertion failure: $x != $y');
  assert(x == y, '$x != $y');
  return equals;
}

/// Returns true if [x] and [y] are equivalent.
bool equalUint8List(Uint8List x, Uint8List y) {
  if (x.length != y.length) return false;
  for (int i = 0; i < x.length; ++i) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

String zeroPadOddLengthString(String x) => x.length % 2 == 0 ? x : '0' + x;

String zeroPadOddLengthHexString(String x) => x.length % 2 == 0
    ? x
    : (x.startsWith('0x') ? ('0x0' + x.substring(2)) : ('0' + x));

/// Prepends [input] with zeros so [input.length] becomes [size].
Uint8List zeroPadUint8List(Uint8List input, int size) {
  if (input.length < size) {
    return Uint8List.fromList(
        List.filled(size - input.length, 0) + input.toList());
  } else if (input.length == size) {
    return input;
  } else {
    return null;
  }
}

/// Returns [n] random bytes.
Uint8List randBytes(int n) {
  final Random generator = Random.secure();
  final Uint8List random = Uint8List(n);
  for (int i = 0; i < random.length; i++) {
    random[i] = generator.nextInt(255);
  }
  return random;
}

/// Splits [debugPrint] into separate calls of [maxPrintLength].
void debugPrintLong(Object object, StringCallback debugPrint) async {
  const int maxPrintLength = 1000;
  if (object == null || object.toString().length <= maxPrintLength) {
    debugPrint(object);
  } else {
    final String text = object.toString();
    int startIndex = 0, endIndex = maxPrintLength;
    int remainingLength = text.length;
    while (endIndex < text.length) {
      debugPrint(text.substring(startIndex, endIndex));
      endIndex += maxPrintLength;
      startIndex += maxPrintLength;
      remainingLength -= maxPrintLength;
    }
    if (remainingLength > 0) debugPrint(text.substring(startIndex));
  }
}

/// Modified [List.map()] providing item [index].
Iterable<E> mapIndexed<E, T>(
    Iterable<T> items, E Function(int index, T item) f) sync* {
  var index = 0;
  for (final item in items) {
    yield f(index, item);
    index = index + 1;
  }
}

/// Saves exception details for presentation.
class ErrorDetails {
  dynamic exception;
  StackTrace stack;
  ErrorDetails({this.exception, this.stack});
}

/// A proto-[Set] implemented as a [List] sorted by [compare].
class SortedListSet<T> {
  List<T> data;
  int Function(T, T) compare;
  SortedListSet(this.compare, this.data);

  bool get isEmpty => data.isEmpty;
  int get length => data.length;
  T get first => data.first;
  T get last => data.last;

  void clear() => data.clear();

  bool add(T value, {bool overwrite = true}) {
    int index = lowerBound(data, value, compare: compare);
    if (index < data.length && compare(data[index], value) == 0) {
      if (overwrite) data[index] = value;
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
