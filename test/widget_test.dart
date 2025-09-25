import 'package:flutter_test/flutter_test.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/model/travel_model.dart';

void main() {
  group('Basic Widget Tests', () {
    test('UserData can be created successfully', () {
      final testUserData = UserData(
        userData: TravelModel(detail: []),
        auth: AuthModel(
          name: 'Test User',
          uid: 'test_id_123',
          avatar: 'https://example.com/avatar.jpg',
          like: [],
          comment: [],
          collect: [],
          follow: [],
          followed: [],
        ),
        traficInfo: [],
        chatArray: [],
        chatUsers: [],
        trips: [],
        points: [],
        index: [],
        picsFromAlbum: [],
        cloneData: TravelModel(detail: []),
      );

      expect(testUserData, isA<UserData>());
      expect(testUserData.userData, isA<TravelModel>());
      expect(testUserData.auth, isA<AuthModel>());
    });
  });
}
