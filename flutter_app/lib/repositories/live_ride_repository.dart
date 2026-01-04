import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/live_ride.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class LiveRideRepository {
  final ApiService _apiService;
  
  // Cache léger pour l'état actuel
  LiveRideState? _currentState;
  DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(seconds: 30);

  LiveRideRepository({required ApiService apiService})
      : _apiService = apiService;

  /// Démarrer une balade en direct
  Future<LiveRideState> startLiveRide({
    required String rideId,
    Map<String, dynamic>? location,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/start');
      
      final body = <String, dynamic>{
        if (location != null) 'location': location,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('[LiveRideRepository] Réponse startLiveRide: ${data.toString()}');
        
        if (data['success'] == true && data['data'] != null) {
          // Le backend renvoie { success: true, data: { ride: {...} } }
          final rideData = data['data']['ride'] ?? data['data'];
          debugPrint('[LiveRideRepository] Ride data: ${rideData.toString()}');
          
          // Transformer le format Ride en format LiveRideState
          final state = LiveRideState.fromJson({
            'ride': {
              '_id': rideData['_id']?.toString() ?? rideData['id']?.toString() ?? rideId,
              'titre': rideData['titre'] ?? 'Balade',
              'status': rideData['status'] ?? 'in_progress',
              'organisateur': rideData['organisateur'],
              'participants': rideData['participants'] ?? [],
            },
            'participantPositions': rideData['participantPositions'] ?? [],
            'lastEvent': rideData['rideEvents'] != null && (rideData['rideEvents'] as List).isNotEmpty
                ? (rideData['rideEvents'] as List).last
                : null,
          });
          _currentState = state;
          _lastFetch = DateTime.now();
          return state;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du démarrage de la balade');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur startLiveRide: $e');
      rethrow;
    }
  }

  /// Mettre en pause une balade
  Future<LiveRideState> pauseLiveRide({
    required String rideId,
    Map<String, dynamic>? location,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/pause');
      
      final body = <String, dynamic>{
        if (location != null) 'location': location,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final state = LiveRideState.fromJson(data['data']);
          _currentState = state;
          _lastFetch = DateTime.now();
          return state;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la mise en pause');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur pauseLiveRide: $e');
      rethrow;
    }
  }

  /// Reprendre une balade en pause
  Future<LiveRideState> resumeLiveRide({
    required String rideId,
    Map<String, dynamic>? location,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/resume');
      
      final body = <String, dynamic>{
        if (location != null) 'location': location,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend renvoie { success: true, data: { ride: {...} } }
          final rideData = data['data']['ride'] ?? data['data'];
          
          // Transformer le format Ride en format LiveRideState
          final state = LiveRideState.fromJson({
            'ride': {
              '_id': rideData['_id']?.toString() ?? rideData['id']?.toString() ?? rideId,
              'titre': rideData['titre'] ?? 'Balade',
              'status': rideData['status'] ?? 'in_progress',
              'organisateur': rideData['organisateur'],
              'participants': rideData['participants'] ?? [],
            },
            'participantPositions': [],
            'lastEvent': rideData['rideEvents'] != null && (rideData['rideEvents'] as List).isNotEmpty
                ? (rideData['rideEvents'] as List).last
                : null,
          });
          _currentState = state;
          _lastFetch = DateTime.now();
          return state;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la reprise');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur resumeLiveRide: $e');
      rethrow;
    }
  }

  /// Terminer une balade
  Future<LiveRideState> endLiveRide({
    required String rideId,
    Map<String, dynamic>? location,
    Map<String, dynamic>? summary,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/end');
      
      final body = <String, dynamic>{
        if (location != null) 'location': location,
        if (summary != null) 'summary': summary,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend renvoie { data: { ride } }, il faut construire le LiveRideState
          final rideData = data['data']['ride'];
          if (rideData != null) {
            // Construire le LiveRideState à partir du ride
            final state = LiveRideState.fromJson({
              'rideId': rideData['_id'] ?? rideData['id'],
              'status': {
                'rideId': rideData['_id'] ?? rideData['id'],
                'titre': rideData['titre'],
                'status': rideData['status'],
                'isActive': rideData['status'] == 'in_progress',
                'organisateur': rideData['organisateur'],
                'participants': rideData['participants'] ?? [],
                'lastEvent': rideData['rideEvents'] != null && (rideData['rideEvents'] as List).isNotEmpty
                    ? (rideData['rideEvents'] as List).last
                    : null,
              },
              'participantPositions': [],
            });
            _currentState = state;
            _lastFetch = DateTime.now();
            return state;
          }
          throw Exception('Format de réponse invalide: ride manquant');
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la fin de la balade');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur endLiveRide: $e');
      rethrow;
    }
  }

  /// Signaler un incident
  Future<LiveRideState> reportIncident({
    required String rideId,
    required String incidentType,
    Map<String, dynamic>? location,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/incident');
      
      final body = <String, dynamic>{
        'incidentType': incidentType,
        if (location != null) 'location': location,
        if (description != null) 'description': description,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final state = LiveRideState.fromJson(data['data']);
          _currentState = state;
          _lastFetch = DateTime.now();
          return state;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du signalement de l\'incident');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur reportIncident: $e');
      rethrow;
    }
  }

  /// Obtenir l'état actuel d'une balade
  Future<LiveRideState> getLiveRideStatus({
    required String rideId,
    bool useCache = true,
  }) async {
    try {
      // Vérifier le cache
      if (useCache && 
          _currentState != null && 
          _lastFetch != null &&
          DateTime.now().difference(_lastFetch!) < _cacheTtl) {
        return _currentState!;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/status');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Le backend renvoie { success: true, data: { status: {...} } }
          final statusData = data['data']['status'] ?? data['data'];
          
          // Le backend renvoie un objet avec rideId, titre, status, isActive, organisateur, participants, lastEvent
          // Il faut le transformer en format attendu par LiveRideState
          final state = LiveRideState.fromJson({
            'ride': {
              '_id': statusData['rideId']?.toString() ?? rideId,
              'titre': statusData['titre'] ?? 'Balade',
              'status': statusData['status'] ?? 'scheduled',
              'organisateur': statusData['organisateur'],
              'participants': statusData['participants'] ?? [],
            },
            'participantPositions': statusData['participantPositions'] ?? [],
            'lastEvent': statusData['lastEvent'],
          });
          _currentState = state;
          _lastFetch = DateTime.now();
          return state;
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération de l\'état');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur getLiveRideStatus: $e');
      rethrow;
    }
  }

  /// Envoyer un heartbeat
  Future<void> sendHeartbeat({
    required String rideId,
    Map<String, dynamic>? location,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/live-rides/$rideId/heartbeat');
      
      final body = <String, dynamic>{
        if (location != null) 'location': location,
      };

      final response = await _apiService.post(uri, body: jsonEncode(body));

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du heartbeat');
      }
    } catch (e) {
      debugPrint('[LiveRideRepository] Erreur sendHeartbeat: $e');
      rethrow;
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _currentState = null;
    _lastFetch = null;
  }
}

