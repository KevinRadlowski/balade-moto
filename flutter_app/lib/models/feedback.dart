class Feedback {
  final String id;
  final String entityType;
  final String entityId;
  final String userId;
  final String feedbackType;
  final int? rating;
  final String? comment;
  final List<String>? categories;
  final String? priority;
  final String status;
  final FeedbackResponse? response;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Feedback({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.feedbackType,
    this.rating,
    this.comment,
    this.categories,
    this.priority,
    required this.status,
    this.response,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] ?? json['_id'] ?? '',
      entityType: json['entityType'] ?? '',
      entityId: json['entityId']?.toString() ?? '',
      userId: json['userId'] is Map 
          ? (json['userId']['_id'] ?? json['userId']['id'] ?? '').toString()
          : json['userId']?.toString() ?? '',
      feedbackType: json['type'] ?? json['feedbackType'] ?? '',
      rating: json['rating'] != null ? (json['rating'] is int ? json['rating'] : json['rating'].toInt()) : null,
      comment: json['comment'],
      categories: json['categories'] != null ? List<String>.from(json['categories']) : null,
      priority: json['priority'],
      status: json['status'] ?? 'pending',
      response: json['response'] != null ? FeedbackResponse.fromJson(json['response']) : null,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feedbackType': feedbackType,
      if (rating != null) 'rating': rating,
      if (comment != null) 'comment': comment,
      if (categories != null) 'categories': categories,
      if (priority != null) 'priority': priority,
    };
  }
}

class FeedbackResponse {
  final String? text;
  final String? respondedBy;
  final DateTime? respondedAt;

  FeedbackResponse({
    this.text,
    this.respondedBy,
    this.respondedAt,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    return FeedbackResponse(
      text: json['text'],
      respondedBy: json['respondedBy']?.toString(),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }
}

class AverageRating {
  final double average;
  final int count;

  AverageRating({
    required this.average,
    required this.count,
  });

  factory AverageRating.fromJson(Map<String, dynamic> json) {
    return AverageRating(
      average: (json['average'] ?? 0).toDouble(),
      count: json['count'] ?? 0,
    );
  }
}

