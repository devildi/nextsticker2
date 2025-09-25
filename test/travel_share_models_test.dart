import 'package:flutter_test/flutter_test.dart';
import 'package:nextsticker2/model/travel_model.dart';

void main() {
  group('Travel Share Models Tests', () {
    group('TravelModel Share Tests', () {
      test('TravelModel copy method should create deep copy', () {
        // Create original travel model with nested data
        final originalDetail = DayDetail(dayList: [
          DetailModel(
            nameOfScence: 'Test Location',
            longitude: '123.456',
            latitude: '78.901',
            des: 'Test description',
            picURL: 'https://example.com/pic.jpg',
            pointOrNot: true,
            contructor: 'test_user',
            category: 1,
            done: false,
          )
        ]);

        final original = TravelModel(
          uid: 'test_travel_id',
          tripName: 'Test Trip',
          designer: 'test_designer',
          city: 'Test City',
          country: 'Test Country',
          tags: 'test,tags',
          cover: 'https://example.com/cover.jpg',
          domestic: 1,
          detail: [originalDetail],
        );

        // Create copy
        final copy = original.copy();

        // Verify deep copy
        expect(copy.uid, equals(original.uid));
        expect(copy.tripName, equals(original.tripName));
        expect(copy.designer, equals(original.designer));
        expect(copy.detail.length, equals(original.detail.length));

        // Verify it's a deep copy, not reference
        expect(identical(copy.detail, original.detail), isFalse);
        expect(identical(copy.detail[0], original.detail[0]), isFalse);
        expect(identical(copy.detail[0].dayList[0], original.detail[0].dayList[0]), isFalse);

        // Modify copy and ensure original is unchanged
        copy.tripName = 'Modified Trip';
        copy.detail[0].dayList[0].nameOfScence = 'Modified Location';

        expect(original.tripName, equals('Test Trip'));
        expect(original.detail[0].dayList[0].nameOfScence, equals('Test Location'));
      });

      test('TravelModel serialization/deserialization for sharing', () {
        final original = TravelModel(
          uid: 'share_test_id',
          tripName: 'Shared Trip',
          designer: 'sharer_user',
          city: 'Paris',
          country: 'France',
          tags: 'romantic,city',
          cover: 'https://example.com/paris.jpg',
          domestic: 0,
          detail: [
            DayDetail(dayList: [
              DetailModel(
                nameOfScence: 'Eiffel Tower',
                longitude: '2.2944',
                latitude: '48.8584',
                des: 'Iconic tower',
                picURL: 'https://example.com/eiffel.jpg',
                category: 1,
              )
            ])
          ],
        );

        // Test JSON conversion for sharing
        final json = original.toJson();
        final reconstructed = TravelModel.fromJson(json);

        expect(reconstructed.uid, equals(original.uid));
        expect(reconstructed.tripName, equals(original.tripName));
        expect(reconstructed.designer, equals(original.designer));
        expect(reconstructed.detail.length, equals(original.detail.length));
        expect(reconstructed.detail[0].dayList[0].nameOfScence,
               equals(original.detail[0].dayList[0].nameOfScence));
      });

      test('TravelModel should handle empty detail for shared trips', () {
        final emptyTrip = TravelModel(
          uid: 'empty_share_id',
          tripName: 'Empty Shared Trip',
          designer: 'test_user',
          detail: [],
        );

        expect(emptyTrip.detail, isEmpty);

        final json = emptyTrip.toJson();
        final reconstructed = TravelModel.fromJson(json);

        expect(reconstructed.detail, isEmpty);
        expect(reconstructed.tripName, equals('Empty Shared Trip'));
      });
    });

    group('AuthModel Share Tests', () {
      test('AuthModel should support sharing user lists', () {
        final user1 = AuthModel(
          name: 'User One',
          uid: 'user_1',
          avatar: 'https://example.com/avatar1.jpg',
          like: [],
          comment: [],
          collect: [],
          follow: [],
          followed: [],
        );

        final user2 = AuthModel(
          name: 'User Two',
          uid: 'user_2',
          avatar: 'https://example.com/avatar2.jpg',
          like: [],
          comment: [],
          collect: [],
          follow: [user1], // User2 follows User1
          followed: [],
        );

        expect(user2.follow.length, equals(1));
        expect(user2.follow[0].uid, equals('user_1'));

        // Test JSON serialization for sharing user data
        final json = user2.toJson();
        expect(json['follow'], isA<List>());
        expect(json['follow'].length, equals(1));
      });

      test('AuthModel should handle collaborative trip collections', () {
        final sharedTrip = TravelModel(
          uid: 'shared_trip_123',
          tripName: 'Collaborative Trip',
          designer: 'main_user',
          detail: [],
        );

        final collaborator = AuthModel(
          name: 'Collaborator',
          uid: 'collab_123',
          avatar: 'https://example.com/collab.jpg',
          like: [sharedTrip], // Liked shared trip
          comment: [],
          collect: [sharedTrip], // Collected shared trip
          follow: [],
          followed: [],
        );

        expect(collaborator.like.length, equals(1));
        expect(collaborator.collect.length, equals(1));
        expect(collaborator.like[0].uid, equals('shared_trip_123'));
        expect(collaborator.collect[0].tripName, equals('Collaborative Trip'));
      });
    });

    group('DetailModel Share Tests', () {
      test('DetailModel copy should preserve sharing state', () {
        final original = DetailModel(
          nameOfScence: 'Shared Location',
          longitude: '100.123',
          latitude: '50.456',
          des: 'Shared by team',
          picURL: 'https://example.com/shared.jpg',
          pointOrNot: true,
          contructor: 'team_member_1',
          category: 2,
          done: false,
        );

        final copy = original.copy();

        expect(copy.nameOfScence, equals(original.nameOfScence));
        expect(copy.contructor, equals(original.contructor));
        expect(copy.category, equals(original.category));
        expect(copy.done, equals(original.done));

        // Verify it's a true copy
        copy.done = true;
        copy.contructor = 'team_member_2';

        expect(original.done, isFalse);
        expect(original.contructor, equals('team_member_1'));
      });

      test('DetailModel should track contributor information', () {
        final sharedPoint = DetailModel(
          nameOfScence: 'Team Location',
          contructor: 'original_creator',
          category: 1,
          done: false,
        );

        expect(sharedPoint.contructor, equals('original_creator'));

        // Simulate modification by another team member
        final modifiedPoint = sharedPoint.copy();
        modifiedPoint.contructor = 'modifier_user';
        modifiedPoint.done = true;

        expect(modifiedPoint.contructor, equals('modifier_user'));
        expect(modifiedPoint.done, isTrue);
        expect(sharedPoint.contructor, equals('original_creator'));
        expect(sharedPoint.done, isFalse);
      });
    });

    group('Comment Share Tests', () {
      test('Comment should support travel sharing discussions', () {
        final commenter = AuthModel(
          name: 'Trip Commenter',
          uid: 'commenter_123',
          avatar: 'https://example.com/commenter.jpg',
          like: [],
          comment: [],
          collect: [],
          follow: [],
          followed: [],
        );

        final shareComment = Comment(
          content: 'This shared trip looks amazing! Can\'t wait to join.',
          whoseContent: commenter,
        );

        expect(shareComment.content, contains('shared trip'));
        expect(shareComment.whoseContent.name, equals('Trip Commenter'));

        // Test JSON serialization for sharing comments
        final json = shareComment.toJson();
        expect(json['content'], equals(shareComment.content));
        expect(json['whoseContent'], equals(commenter));
      });

      test('Comment fromJson should handle shared comment data', () {
        final commentJson = {
          'content': 'Great collaborative planning session!',
          'whoseContent': {
            'name': 'Team Member',
            '_id': 'team_member_456',
            'avatar': 'https://example.com/team.jpg',
            'like': [],
            'comment': [],
            'collect': [],
            'follow': [],
            'followed': [],
          },
        };

        final comment = Comment.fromJson(commentJson);

        expect(comment.content, equals('Great collaborative planning session!'));
        expect(comment.whoseContent.name, equals('Team Member'));
        expect(comment.whoseContent.uid, equals('team_member_456'));
      });
    });

    group('AllTrip Share Tests', () {
      test('AllTrip should handle shared trip collections', () {
        final sharedTrips = [
          TravelModel(
            uid: 'shared_1',
            tripName: 'Public Trip 1',
            designer: 'designer_1',
            detail: [],
          ),
          TravelModel(
            uid: 'shared_2',
            tripName: 'Public Trip 2',
            designer: 'designer_2',
            detail: [],
          ),
        ];

        final allTrips = AllTrip(allTripList: sharedTrips);

        expect(allTrips.allTripList.length, equals(2));
        expect(allTrips.allTripList[0].tripName, equals('Public Trip 1'));
        expect(allTrips.allTripList[1].tripName, equals('Public Trip 2'));
      });

      test('AllTrip fromJson should parse shared trip feed', () {
        final sharedTripsJson = [
          {
            'uid': 'public_trip_1',
            'tripName': 'Amazing Europe Tour',
            'designer': 'travel_expert',
            'city': 'Paris',
            'country': 'France',
            'tags': 'culture,history',
            'cover': 'https://example.com/europe.jpg',
            'domestic': 0,
            'detail': [],
          },
          {
            'uid': 'public_trip_2',
            'tripName': 'Asia Adventure',
            'designer': 'adventure_seeker',
            'city': 'Tokyo',
            'country': 'Japan',
            'tags': 'adventure,food',
            'cover': 'https://example.com/asia.jpg',
            'domestic': 0,
            'detail': [],
          }
        ];

        final allTrips = AllTrip.fromJson(sharedTripsJson);

        expect(allTrips.allTripList.length, equals(2));
        expect(allTrips.allTripList[0].tripName, equals('Amazing Europe Tour'));
        expect(allTrips.allTripList[0].designer, equals('travel_expert'));
        expect(allTrips.allTripList[1].tripName, equals('Asia Adventure'));
        expect(allTrips.allTripList[1].tags, equals('adventure,food'));
      });
    });

    group('Data Integrity Tests for Sharing', () {
      test('Shared data should maintain referential integrity', () {
        final originalCreator = AuthModel(
          name: 'Original Creator',
          uid: 'creator_123',
          avatar: 'https://example.com/creator.jpg',
          like: [],
          comment: [],
          collect: [],
          follow: [],
          followed: [],
        );

        final collaborativeTrip = TravelModel(
          uid: 'collab_trip_789',
          tripName: 'Team Planning Trip',
          designer: 'creator_123',
          detail: [
            DayDetail(dayList: [
              DetailModel(
                nameOfScence: 'Meeting Point',
                contructor: 'creator_123',
                category: 0,
              )
            ])
          ],
        );

        // Verify creator ID consistency
        expect(collaborativeTrip.designer, equals(originalCreator.uid));
        expect(collaborativeTrip.detail[0].dayList[0].contructor, equals(originalCreator.uid));
      });
    });
  });
}