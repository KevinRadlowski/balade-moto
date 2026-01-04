import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:balades_moto/repositories/live_ride_repository.dart';
import 'package:balades_moto/services/api_service.dart';

@GenerateMocks([ApiService])
import 'live_ride_repository_test.mocks.dart';

void main() {
  late LiveRideRepository repository;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    repository = LiveRideRepository(apiService: mockApiService);
  });

  group('LiveRideRepository', () {
    test('startLiveRide should return LiveRideState on success', () async {
      // Arrange
      final responseData = {
        'success': true,
        'data': {
          'ride': {
            '_id': 'ride123',
            'titre': 'Test Ride',
            'status': 'in_progress',
            'participants': [],
          },
          'participantPositions': [],
        }
      };

      final response = http.Response(
        jsonEncode(responseData),
        200,
        headers: {'Content-Type': 'application/json'},
      );

      when(mockApiService.post(
        any,
        body: anyNamed('body'),
      )).thenAnswer((_) async => response);

      // Act
      final state = await repository.startLiveRide(rideId: 'ride123');

      // Assert
      expect(state.ride.id, 'ride123');
      expect(state.ride.status, 'in_progress');
    });

    test('getLiveRideStatus should return LiveRideState', () async {
      // Arrange
      final responseData = {
        'success': true,
        'data': {
          'ride': {
            '_id': 'ride123',
            'titre': 'Test Ride',
            'status': 'in_progress',
            'participants': [],
          },
          'participantPositions': [],
        }
      };

      final response = http.Response(
        jsonEncode(responseData),
        200,
        headers: {'Content-Type': 'application/json'},
      );

      when(mockApiService.get(any)).thenAnswer((_) async => response);

      // Act
      final state = await repository.getLiveRideStatus(rideId: 'ride123');

      // Assert
      expect(state.ride.id, 'ride123');
    });
  });
}

