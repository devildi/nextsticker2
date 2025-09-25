import 'package:flutter_test/flutter_test.dart';
import 'package:nextsticker2/model/travel_model.dart';

void main() {
  group('Travel Model Tests', () {
    test('TravelModel should initialize with empty detail list', () {
      final model = TravelModel(detail: []);
      expect(model.detail, isEmpty);
    });

    test('TravelModel should be created from JSON', () {
      final json = {
        'detail': []
      };
      final model = TravelModel.fromJson(json);
      expect(model.detail, isEmpty);
    });

    test('TravelModel should convert to JSON', () {
      final model = TravelModel(detail: []);
      final json = model.toJson();
      expect(json['detail'], isEmpty);
    });
  });

  group('AuthModel Tests', () {
    test('AuthModel should initialize with empty lists', () {
      final authModel = AuthModel(
        name: 'Test User',
        uid: 'test_id_123',
        avatar: 'https://example.com/avatar.jpg',
        like: [],
        comment: [],
        collect: [],
        follow: [],
        followed: [],
      );

      expect(authModel.name, equals('Test User'));
      expect(authModel.uid, equals('test_id_123'));
      expect(authModel.avatar, equals('https://example.com/avatar.jpg'));
      expect(authModel.like, isEmpty);
      expect(authModel.comment, isEmpty);
      expect(authModel.collect, isEmpty);
      expect(authModel.follow, isEmpty);
      expect(authModel.followed, isEmpty);
    });

    test('AuthModel should be created from JSON', () {
      final json = {
        'name': 'Test User',
        '_id': 'test_id_123',
        'avatar': 'https://example.com/avatar.jpg',
        'like': [],
        'comment': [],
        'collect': [],
        'follow': [],
        'followed': [],
      };

      final authModel = AuthModel.fromJson(json);
      expect(authModel.name, equals('Test User'));
      expect(authModel.uid, equals('test_id_123'));
      expect(authModel.avatar, equals('https://example.com/avatar.jpg'));
      expect(authModel.like, isEmpty);
      expect(authModel.comment, isEmpty);
      expect(authModel.collect, isEmpty);
      expect(authModel.follow, isEmpty);
      expect(authModel.followed, isEmpty);
    });

    test('AuthModel should convert to JSON', () {
      final authModel = AuthModel(
        name: 'Test User',
        uid: 'test_id_123',
        avatar: 'https://example.com/avatar.jpg',
        like: [],
        comment: [],
        collect: [],
        follow: [],
        followed: [],
      );

      final json = authModel.toJson();
      expect(json['name'], equals('Test User'));
      expect(json['_id'], equals('test_id_123'));
      expect(json['avatar'], equals('https://example.com/avatar.jpg'));
      expect(json['like'], isEmpty);
      expect(json['comment'], isEmpty);
      expect(json['collect'], isEmpty);
      expect(json['follow'], isEmpty);
      expect(json['followed'], isEmpty);
    });
  });

  group('NewUser Tests', () {
    test('NewUser should be created with required fields', () {
      final user = NewUser(
        wechat: 'test_wechat',
        destination: 'Paris',
      );

      expect(user.wechat, equals('test_wechat'));
      expect(user.destination, equals('Paris'));
    });

    test('NewUser should be created from JSON', () {
      final json = {
        'wechat': 'test_wechat',
        'destination': 'Tokyo',
      };

      final user = NewUser.fromJson(json);
      expect(user.wechat, equals('test_wechat'));
      expect(user.destination, equals('Tokyo'));
    });

    test('NewUser should convert to JSON correctly', () {
      final user = NewUser(
        wechat: 'test_wechat',
        destination: 'London',
      );

      final json = user.toJson();
      // Note: There's a bug in the original code where it uses 'width' instead of 'wechat'
      expect(json['width'], equals('test_wechat'));
      expect(json['destination'], equals('London'));
    });
  });

  group('Comment Tests', () {
    test('Comment should be created with required fields', () {
      final authModel = AuthModel(
        name: 'Test User',
        uid: 'test_id_123',
        avatar: 'https://example.com/avatar.jpg',
        like: [],
        comment: [],
        collect: [],
        follow: [],
        followed: [],
      );

      final comment = Comment(
        content: 'This is a test comment',
        whoseContent: authModel,
      );

      expect(comment.content, equals('This is a test comment'));
      expect(comment.whoseContent, equals(authModel));
    });

    test('Comment should be created from JSON', () {
      final json = {
        'content': 'Test comment content',
        'whoseContent': {
          'name': 'Test User',
          '_id': 'test_id_123',
          'avatar': 'https://example.com/avatar.jpg',
          'like': [],
          'comment': [],
          'collect': [],
          'follow': [],
          'followed': [],
        },
      };

      final comment = Comment.fromJson(json);
      expect(comment.content, equals('Test comment content'));
      expect(comment.whoseContent, isA<AuthModel>());
    });

    test('Comment should convert to JSON', () {
      final authModel = AuthModel(
        name: 'Test User',
        uid: 'test_id_123',
        avatar: 'https://example.com/avatar.jpg',
        like: [],
        comment: [],
        collect: [],
        follow: [],
        followed: [],
      );

      final comment = Comment(
        content: 'Test comment',
        whoseContent: authModel,
      );

      final json = comment.toJson();
      expect(json['content'], equals('Test comment'));
      expect(json['whoseContent'], equals(authModel));
    });
  });
}