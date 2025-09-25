import 'package:flutter_test/flutter_test.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/model/travel_model.dart';

void main() {
  group('UserData Store Tests', () {
    late UserData userData;

    setUp(() {
      userData = UserData(
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
    });

    test('UserData should initialize with correct default values', () {
      expect(userData.domestic, equals(true));
      expect(userData.whichForDrawer, equals(-1));
      expect(userData.netWorkStatus, equals(true));
      expect(userData.loadingRouteState, equals(false));
      expect(userData.numInChatroom, equals(0));
      expect(userData.loading, equals(false));
      expect(userData.picBing, equals(''));
      expect(userData.des, equals(''));
      expect(userData.category, equals(0));
      expect(userData.swiperIndex, equals(0));
      expect(userData.fetchImgStatus, equals('正在完善信息中，请耐心等待...'));
    });

    test('UserData should initialize with provided data', () {
      expect(userData.userData, isA<TravelModel>());
      expect(userData.auth, isA<AuthModel>());
      expect(userData.traficInfo, isEmpty);
      expect(userData.chatArray, isEmpty);
      expect(userData.chatUsers, isEmpty);
      expect(userData.trips, isEmpty);
      expect(userData.points, isEmpty);
      expect(userData.index, isEmpty);
      expect(userData.picsFromAlbum, isEmpty);
      expect(userData.cloneData, isA<TravelModel>());
    });

    test('UserData should update category', () {
      userData.category = 2;
      expect(userData.category, equals(2));
    });

    test('UserData should update swiperIndex', () {
      userData.swiperIndex = 3;
      expect(userData.swiperIndex, equals(3));
    });

    test('UserData should update fetchImgStatus', () {
      const newStatus = 'Loading complete';
      userData.fetchImgStatus = newStatus;
      expect(userData.fetchImgStatus, equals(newStatus));
    });

    test('UserData should update domestic flag', () {
      userData.domestic = false;
      expect(userData.domestic, equals(false));
    });

    test('UserData should update network status', () {
      userData.netWorkStatus = false;
      expect(userData.netWorkStatus, equals(false));
    });

    test('UserData should update loading state', () {
      userData.loading = true;
      expect(userData.loading, equals(true));
    });

    test('UserData should update loadingRouteState', () {
      userData.loadingRouteState = true;
      expect(userData.loadingRouteState, equals(true));
    });

    test('UserData should update whichForDrawer', () {
      userData.whichForDrawer = 5;
      expect(userData.whichForDrawer, equals(5));
    });

    test('UserData should update numInChatroom', () {
      userData.numInChatroom = 10;
      expect(userData.numInChatroom, equals(10));
    });

    test('UserData should update picBing', () {
      const newPicBing = 'https://example.com/image.jpg';
      userData.picBing = newPicBing;
      expect(userData.picBing, equals(newPicBing));
    });

    test('UserData should update description', () {
      const newDes = 'New description';
      userData.des = newDes;
      expect(userData.des, equals(newDes));
    });

    test('UserData should be a ChangeNotifier', () {
      expect(userData, isA<UserData>());
      // UserData extends ChangeNotifier, so we can test notification behavior
      var notified = false;
      userData.addListener(() {
        notified = true;
      });

      // Manually trigger notification (in real app, this would be called when state changes)
      userData.notifyListeners();
      expect(notified, equals(true));
    });
  });
}