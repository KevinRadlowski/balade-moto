import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:balades_moto/repositories/feedback_repository.dart';
import 'package:balades_moto/services/api_service.dart';
import 'package:balades_moto/config/api_config.dart';

@GenerateMocks([ApiService])
import 'feedback_repository_test.mocks.dart';

void main() {
  late FeedbackRepository repository;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    repository = FeedbackRepository(apiService: mockApiService);
  });

  group('FeedbackRepository', () {
    test('createFeedback should return Feedback on success', () async {
      // Arrange
      final responseData = {
        'success': true,
        'data': {
          'id': 'feedback123',
          'entityType': 'ride',
          'entityId': 'ride123',
          'userId': 'user123',
          'feedbackType': 'rating',
          'rating': 5,
          'comment': 'Great ride!',
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }
      };

      final response = http.Response(
        jsonEncode(responseData),
        201,
        headers: {'Content-Type': 'application/json'},
      );

      when(mockApiService.post(
        any,
        body: anyNamed('body'),
      )).thenAnswer((_) async => response);

      // Act
      final feedback = await repository.createFeedback(
        rideId: 'ride123',
        feedbackType: 'rating',
        rating: 5,
        comment: 'Great ride!',
      );

      // Assert
      expect(feedback.id, 'feedback123');
      expect(feedback.feedbackType, 'rating');
      expect(feedback.rating, 5);
      expect(feedback.comment, 'Great ride!');
    });

    test('getRideFeedbacks should return list of Feedback', () async {
      // Arrange
      final responseData = {
        'success': true,
        'data': [
          {
            'id': 'feedback1',
            'entityType': 'ride',
            'entityId': 'ride123',
            'userId': 'user123',
            'feedbackType': 'rating',
            'rating': 5,
            'status': 'pending',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ]
      };

      final response = http.Response(
        jsonEncode(responseData),
        200,
        headers: {'Content-Type': 'application/json'},
      );

      when(mockApiService.get(any)).thenAnswer((_) async => response);

      // Act
      final feedbacks = await repository.getRideFeedbacks(rideId: 'ride123');

      // Assert
      expect(feedbacks.length, 1);
      expect(feedbacks.first.id, 'feedback1');
    });

    test('getAverageRating should return AverageRating', () async {
      // Arrange
      final responseData = {
        'success': true,
        'data': {
          'average': 4.5,
          'count': 10,
        }
      };

      final response = http.Response(
        jsonEncode(responseData),
        200,
        headers: {'Content-Type': 'application/json'},
      );

      when(mockApiService.get(any)).thenAnswer((_) async => response);

      // Act
      final rating = await repository.getAverageRating(rideId: 'ride123');

      // Assert
      expect(rating.average, 4.5);
      expect(rating.count, 10);
    });
  });
}

