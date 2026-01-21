/// Pure Dart map equality utility - replaces Flutter's mapEquals.
///
/// This function compares two maps for deep equality without
/// requiring Flutter dependencies.

/// Compares two maps for shallow equality.
///
/// Returns true if both maps contain the same keys and the values
/// for each key are equal according to the `==` operator.
bool mapsEqual<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;

  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }
  return true;
}

/// Compares two maps for deep equality.
///
/// Returns true if both maps contain the same keys and the values
/// for each key are deeply equal (recursively comparing nested maps).
bool mapsDeepEqual<K>(Map<K, dynamic>? a, Map<K, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;

  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;

    final valueA = a[key];
    final valueB = b[key];

    if (valueA is Map<K, dynamic> && valueB is Map<K, dynamic>) {
      if (!mapsDeepEqual(valueA, valueB)) return false;
    } else if (valueA is List && valueB is List) {
      if (!listsDeepEqual(valueA, valueB)) return false;
    } else if (valueA != valueB) {
      return false;
    }
  }
  return true;
}

/// Compares two lists for deep equality.
bool listsDeepEqual(List<dynamic>? a, List<dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    final valueA = a[i];
    final valueB = b[i];

    if (valueA is Map && valueB is Map) {
      if (!mapsDeepEqual(valueA as Map<dynamic, dynamic>,
          valueB as Map<dynamic, dynamic>)) {
        return false;
      }
    } else if (valueA is List && valueB is List) {
      if (!listsDeepEqual(valueA, valueB)) return false;
    } else if (valueA != valueB) {
      return false;
    }
  }
  return true;
}
