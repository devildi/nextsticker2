import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:nextsticker2/model/travel_model.dart';

import 'travel_share_dao_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  group('Travel Share DAO Tests', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    group('Share Trip Creation Tests', () {
      test('save should create shareable trip successfully', () async {
        // Arrange
        final shareableTrip = {
          'uid': 'new_shared_trip',
          'tripName': 'Shared Adventure',
          'designer': 'creator_user',
          'city': 'Barcelona',
          'country': 'Spain',
          'tags': 'beach,culture',
          'cover': 'https://example.com/barcelona.jpg',
          'domestic': 0,
          'detail': [
            [
              {
                'nameOfScence': 'Sagrada Familia',
                'longitude': '2.1734',
                'latitude': '41.4036',
                'des': 'Beautiful basilica',
                'picURL': 'https://example.com/sagrada.jpg',
                'pointOrNot': true,
                'contructor': 'creator_user',
                'category': 1,
                'done': false,
              }
            ]
          ],
          'isShared': true,
          'sharePermissions': 'public',
          'collaborators': ['creator_user'],
        };

        final mockResponse = Response(
          data: shareableTrip,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.save(shareableTrip);

        // Assert
        expect(result, isA<TravelModel>());
        expect(result.tripName, equals('Shared Adventure'));
        expect(result.designer, equals('creator_user'));
        expect(result.city, equals('Barcelona'));
        expect(result.detail.length, equals(1));
        verify(mockDio.post(any, data: shareableTrip)).called(1);
      });

      test('save should handle empty response for sharing', () async {
        // Arrange
        final mockResponse = Response(
          data: '',
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.save({'test': 'data'});

        // Assert
        expect(result, isA<TravelModel>());
        expect(result.detail, isEmpty);
        verify(mockDio.post(any, data: {'test': 'data'})).called(1);
      });
    });

    group('Shared Trip Retrieval Tests', () {
      test('fetchAll should retrieve shared trips by user', () async {
        // Arrange
        final sharedTripsData = [
          {
            'uid': 'shared_trip_1',
            'tripName': 'Shared Europe Tour',
            'designer': 'user_123',
            'city': 'Paris',
            'country': 'France',
            'detail': [],
            'isShared': true,
            'collaborators': ['user_123', 'user_456'],
          },
          {
            'uid': 'shared_trip_2',
            'tripName': 'Collaborative Asia Trip',
            'designer': 'user_456',
            'city': 'Tokyo',
            'country': 'Japan',
            'detail': [],
            'isShared': true,
            'collaborators': ['user_456', 'user_123'],
          }
        ];

        final mockResponse = Response(
          data: sharedTripsData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(any))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.fetchAll('user_123', 1);

        // Assert
        expect(result, isA<AllTrip>());
        expect(result.allTripList.length, equals(2));
        expect(result.allTripList[0].tripName, equals('Shared Europe Tour'));
        expect(result.allTripList[1].tripName, equals('Collaborative Asia Trip'));
        verify(mockDio.get(contains('uid=user_123&page=1'))).called(1);
      });

      test('fetchAll should handle no shared trips (204)', () async {
        // Arrange
        final mockResponse = Response(
          data: null,
          statusCode: 204,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(any))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.fetchAll('user_no_trips', 1);

        // Assert
        expect(result, isA<AllTrip>());
        expect(result.allTripList, isEmpty);
        verify(mockDio.get(contains('uid=user_no_trips&page=1'))).called(1);
      });

      test('fetchAllByDescription should find shared trips by description', () async {
        // Arrange
        final searchResults = [
          {
            'uid': 'found_trip_1',
            'tripName': 'Beach Paradise',
            'designer': 'beach_lover',
            'city': 'Maldives',
            'country': 'Maldives',
            'tags': 'beach,luxury',
            'detail': [],
            'isShared': true,
          }
        ];

        final mockResponse = Response(
          data: searchResults,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(any))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.fetchAllByDescription('beach vacation');

        // Assert
        expect(result, isA<AllTrip>());
        expect(result.allTripList.length, equals(1));
        expect(result.allTripList[0].tripName, equals('Beach Paradise'));
        expect(result.allTripList[0].tags, contains('beach'));
        verify(mockDio.get(contains('description=beach vacation'))).called(1);
      });

      test('fetch should get specific shared trip', () async {
        // Arrange
        final sharedTripData = {
          'uid': 'specific_shared_trip',
          'tripName': 'Mountain Adventure',
          'designer': 'mountain_guide',
          'city': 'Chamonix',
          'country': 'France',
          'tags': 'mountains,skiing',
          'detail': [
            [
              {
                'nameOfScence': 'Mont Blanc',
                'longitude': '6.8652',
                'latitude': '45.8326',
                'des': 'Highest peak in Western Europe',
                'picURL': 'https://example.com/montblanc.jpg',
                'pointOrNot': true,
                'contructor': 'mountain_guide',
                'category': 2,
                'done': false,
              }
            ]
          ],
          'isShared': true,
          'collaborators': ['mountain_guide', 'climber_123'],
        };

        final mockResponse = Response(
          data: sharedTripData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(any))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.fetch('specific_shared_trip');

        // Assert
        expect(result, isA<TravelModel>());
        expect(result.tripName, equals('Mountain Adventure'));
        expect(result.designer, equals('mountain_guide'));
        expect(result.detail.length, equals(1));
        expect(result.detail[0].dayList[0].nameOfScence, equals('Mont Blanc'));
        verify(mockDio.get(contains('specific_shared_trip'))).called(1);
      });
    });

    group('Collaborative Point Updates Tests', () {
      test('updatePoint should update shared point with collaborator info', () async {
        // Arrange
        final updatedTripData = {
          'uid': 'collab_trip_123',
          'tripName': 'Updated Collaborative Trip',
          'detail': [
            [
              {
                'nameOfScence': 'Updated Location',
                'longitude': '123.456',
                'latitude': '78.901',
                'des': 'Updated by collaborator',
                'picURL': 'https://example.com/updated.jpg',
                'pointOrNot': true,
                'contructor': 'collaborator_456',
                'category': 1,
                'done': true,
              }
            ]
          ],
        };

        final mockResponse = Response(
          data: updatedTripData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.updatePoint(
          'collab_trip_123',
          'Updated Location',
          'Updated by collaborator',
          'https://example.com/updated.jpg',
        );

        // Assert
        expect(result, isA<TravelModel>());
        expect(result.tripName, equals('Updated Collaborative Trip'));
        expect(result.detail[0].dayList[0].nameOfScence, equals('Updated Location'));
        expect(result.detail[0].dayList[0].des, equals('Updated by collaborator'));

        // Verify the request was made with correct data
        verify(mockDio.post(
          any,
          data: {
            'uid': 'collab_trip_123',
            'nameOfScence': 'Updated Location',
            'des': 'Updated by collaborator',
            'picURL': 'https://example.com/updated.jpg',
          },
        )).called(1);
      });

      test('updatePoint should handle update failure', () async {
        // Arrange
        when(mockDio.post(any, data: anyNamed('data')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              message: 'Update failed',
            ));

        // Act & Assert
        expect(
          () => TravelDao.updatePoint(
            'invalid_trip',
            'Test Name',
            'Test Description',
            'Test URL',
          ),
          throwsException,
        );
      });
    });

    group('Trip Deletion in Sharing Context Tests', () {
      test('deleteTrip should handle shared trip deletion', () async {
        // Arrange
        final deletionResponse = {
          'message': 'Trip deleted successfully',
          'deletedTripId': 'shared_trip_to_delete',
          'affectedCollaborators': ['user_123', 'user_456'],
        };

        final mockResponse = Response(
          data: deletionResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.deleteTrip('shared_trip_to_delete');

        // Assert
        expect(result, equals(deletionResponse));
        verify(mockDio.post(
          any,
          data: {'uid': 'shared_trip_to_delete'},
        )).called(1);
      });

      test('deleteTrip should handle deletion failure', () async {
        // Arrange
        final mockResponse = Response(
          data: null,
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.post(any, data: anyNamed('data')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => TravelDao.deleteTrip('nonexistent_trip'),
          throwsException,
        );
      });
    });

    group('AI Integration for Shared Trips Tests', () {
      test('fromLLM should create trip from AI for sharing', () async {
        // Arrange
        final aiGeneratedDetail = [
          [
            {
              'nameOfScence': 'AI Recommended Spot',
              'longitude': '2.3522',
              'latitude': '48.8566',
              'des': 'Generated by AI based on preferences',
              'picURL': 'https://example.com/ai-spot.jpg',
              'pointOrNot': true,
              'contructor': 'ai_assistant',
              'category': 1,
              'done': false,
            }
          ]
        ];

        final mockResponse = Response(
          data: aiGeneratedDetail.toString(),
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(any))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.fromLLM('Create a Paris itinerary for sharing');

        // Assert
        expect(result, isA<TravelModel>());
        expect(result.detail, isNotEmpty);
        verify(mockDio.get(contains('chat=Create a Paris itinerary for sharing'))).called(1);
      });

      test('getInfos should provide location info for shared planning', () async {
        // Arrange
        final locationInfo = {
          'city': 'Rome',
          'country': 'Italy',
          'tags': 'history,art,food',
        };

        final mockResponse = Response(
          data: locationInfo.toString(),
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(mockDio.get(any))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await TravelDao.getInfos('Rome travel information');

        // Assert
        expect(result, isA<ReturnInfos>());
        expect(result.city, equals('Rome'));
        expect(result.country, equals('Italy'));
        expect(result.tags, equals('history,art,food'));
        verify(mockDio.get(contains('chat=Rome travel information'))).called(1);
      });
    });

    group('Network Error Handling Tests', () {
      test('should handle network errors gracefully', () async {
        // Arrange
        when(mockDio.get(any))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.connectionTimeout,
              message: 'Connection timeout',
            ));

        // Act & Assert
        expect(
          () => TravelDao.fetch('test_trip'),
          throwsException,
        );
      });

      test('should handle server errors for sharing operations', () async {
        // Arrange
        when(mockDio.post(any, data: anyNamed('data')))
            .thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.badResponse,
              response: Response(
                statusCode: 500,
                requestOptions: RequestOptions(path: ''),
              ),
            ));

        // Act & Assert
        expect(
          () => TravelDao.save({'test': 'data'}),
          throwsException,
        );
      });
    });
  });
}