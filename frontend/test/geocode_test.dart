import 'package:flutter_test/flutter_test.dart';

import 'package:nowcast/src/utils/geocode.dart';

void main() {
  group('addressFromGeocode', () {
    test('extracts the formatted address from the first result', () {
      final address = addressFromGeocode(<String, dynamic>{
        'results': <dynamic>[
          <String, dynamic>{'formattedAddress': 'New York, NY, USA'},
        ],
      });
      expect(address, 'New York, NY, USA');
    });

    test('returns null when the payload is not a map', () {
      expect(addressFromGeocode('nope'), isNull);
    });

    test('returns null when there are no results', () {
      expect(addressFromGeocode(<String, dynamic>{'results': <dynamic>[]}),
          isNull);
    });

    test('returns null when the first result has no formatted address', () {
      final address = addressFromGeocode(<String, dynamic>{
        'results': <dynamic>[<String, dynamic>{'placeId': 'abc'}],
      });
      expect(address, isNull);
    });
  });
}