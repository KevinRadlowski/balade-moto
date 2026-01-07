import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/vehicle.dart';
import '../models/odometer_entry.dart';
import '../models/maintenance_item.dart';
import '../models/maintenance_log.dart';
import '../models/vehicle_document.dart';
import '../config/api_config.dart';
import '../exceptions/plan_limit_exception.dart';

class GarageService {
  final FlutterSecureStorage _storage;

  GarageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String basePath = '/garage';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _makeRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn();
      // Gestion basique des erreurs 401
      if (response.statusCode == 401) {
        // Le token pourrait être expiré, ApiService devrait gérer le refresh
        // Pour l'instant, on laisse l'erreur remonter
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Liste paginée des véhicules de l'utilisateur
  Future<Map<String, dynamic>> listVehicles({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final vehicles = (data['data']['vehicles'] as List)
              .map((v) => Vehicle.fromJson(v))
              .toList();
          return {
            'vehicles': vehicles,
            'pagination': data['data']['pagination'],
          };
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des véhicules');
      }
    } catch (e) {
      debugPrint('Erreur listVehicles: $e');
      rethrow;
    }
  }

  /// Créer un nouveau véhicule
  Future<Vehicle> createVehicle(Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.post(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['vehicle'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('[GarageService] createVehicle errorData: ${jsonEncode(errorData)}');
        
        // Vérifier si c'est une erreur de limite de plan
        if (response.statusCode == 403 && errorData['code'] == 'PLAN_LIMIT') {
          throw PlanLimitException.fromJson(errorData);
        }
        
        // Gérer les erreurs de validation avec détails
        if (errorData['errors'] != null && errorData['errors'] is List) {
          final errors = errorData['errors'] as List;
          final errorMessages = errors.map((e) {
            if (e is Map && e['field'] != null && e['message'] != null) {
              return '${e['field']}: ${e['message']}';
            }
            return e.toString();
          }).join('\n');
          throw Exception('Erreurs de validation:\n$errorMessages');
        }
        throw Exception(errorData['message'] ?? 'Erreur lors de la création du véhicule');
      }
    } catch (e) {
      debugPrint('Erreur createVehicle: $e');
      rethrow;
    }
  }

  /// Récupérer un véhicule par son ID
  Future<Vehicle> getVehicle(String id) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$id');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['vehicle'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du véhicule');
      }
    } catch (e) {
      debugPrint('Erreur getVehicle: $e');
      rethrow;
    }
  }

  /// Mettre à jour un véhicule
  Future<Vehicle> updateVehicle(String id, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$id');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.patch(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['vehicle'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du véhicule');
      }
    } catch (e) {
      debugPrint('Erreur updateVehicle: $e');
      rethrow;
    }
  }

  /// Supprimer un véhicule
  Future<void> deleteVehicle(String id) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$id');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.delete(uri, headers: headers),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du véhicule');
      }
    } catch (e) {
      debugPrint('Erreur deleteVehicle: $e');
      rethrow;
    }
  }

  /// Ajouter une entrée odomètre
  Future<OdometerEntry> addOdometerEntry(String vehicleId, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/odometer');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.post(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['odometerEntry'] != null) {
          return OdometerEntry.fromJson(data['data']['odometerEntry']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'ajout du relevé odomètre');
      }
    } catch (e) {
      debugPrint('Erreur addOdometerEntry: $e');
      rethrow;
    }
  }

  /// Liste paginée des entrées odomètre
  Future<Map<String, dynamic>> listOdometerEntries(
    String vehicleId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/odometer')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final entries = (data['data']['odometerEntries'] as List)
              .map((e) => OdometerEntry.fromJson(e))
              .toList();
          return {
            'odometerEntries': entries,
            'pagination': data['data']['pagination'],
          };
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des relevés odomètre');
      }
    } catch (e) {
      debugPrint('Erreur listOdometerEntries: $e');
      rethrow;
    }
  }

  /// Récupérer le dashboard de maintenance
  Future<Map<String, dynamic>> getMaintenanceDashboard(String vehicleId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/dashboard');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final dashboard = data['data']['dashboard'];
          final dueItems = (dashboard['due'] as List)
              .map((item) => MaintenanceItem.fromJson(item))
              .toList();
          final upcomingItems = (dashboard['upcoming'] as List)
              .map((item) => MaintenanceItem.fromJson(item))
              .toList();
          final okItems = (dashboard['ok'] as List)
              .map((item) => MaintenanceItem.fromJson(item))
              .toList();
          
          return {
            'vehicle': data['data']['vehicle'],
            'due': dueItems,
            'upcoming': upcomingItems,
            'ok': okItems,
            'summary': data['data']['summary'],
          };
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du dashboard');
      }
    } catch (e) {
      debugPrint('Erreur getMaintenanceDashboard: $e');
      rethrow;
    }
  }

  /// Créer un élément de maintenance
  Future<MaintenanceItem> createMaintenanceItem(
    String vehicleId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/items');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.post(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['maintenanceItem'] != null) {
          return MaintenanceItem.fromJson(data['data']['maintenanceItem']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la création de l\'élément de maintenance');
      }
    } catch (e) {
      debugPrint('Erreur createMaintenanceItem: $e');
      rethrow;
    }
  }

  /// Mettre à jour un élément de maintenance
  Future<MaintenanceItem> updateMaintenanceItem(
    String vehicleId,
    String itemId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/items/$itemId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.patch(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['maintenanceItem'] != null) {
          return MaintenanceItem.fromJson(data['data']['maintenanceItem']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour de l\'élément de maintenance');
      }
    } catch (e) {
      debugPrint('Erreur updateMaintenanceItem: $e');
      rethrow;
    }
  }

  /// Supprimer un élément de maintenance
  Future<void> deleteMaintenanceItem(String vehicleId, String itemId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/items/$itemId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.delete(uri, headers: headers),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression de l\'élément de maintenance');
      }
    } catch (e) {
      debugPrint('Erreur deleteMaintenanceItem: $e');
      rethrow;
    }
  }

  /// Créer un log de maintenance (avec fichier optionnel)
  Future<MaintenanceLog> createMaintenanceLog(
    String vehicleId,
    Map<String, dynamic> payload, {
    PlatformFile? file,
    String? filePath,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/logs');

      // Si un fichier est fourni, utiliser multipart
      if (file != null) {
        final request = http.MultipartRequest('POST', uri);
        final token = await _storage.read(key: 'token');
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        // Ajouter les champs du payload
        payload.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        // Ajouter le fichier
        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes(
            'document', // Nom du champ attendu par le backend
            file.bytes!,
            filename: file.name,
          ));
        } else if (filePath != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'document', // Nom du champ attendu par le backend
            filePath,
            filename: file.name,
          ));
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data']['maintenanceLog'] != null) {
            return MaintenanceLog.fromJson(data['data']['maintenanceLog']);
          }
          throw Exception('Format de réponse invalide');
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la création du log de maintenance');
        }
      } else {
        // Pas de fichier, utiliser JSON classique
        final headers = await _getHeaders();
        
        final response = await _makeRequest(
          () => http.post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          ),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data']['maintenanceLog'] != null) {
            return MaintenanceLog.fromJson(data['data']['maintenanceLog']);
          }
          throw Exception('Format de réponse invalide');
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la création du log de maintenance');
        }
      }
    } catch (e) {
      debugPrint('Erreur createMaintenanceLog: $e');
      rethrow;
    }
  }

  /// Récupérer un log de maintenance spécifique
  Future<MaintenanceLog> getMaintenanceLog(
    String vehicleId,
    String logId,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/logs/$logId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['maintenanceLog'] != null) {
          return MaintenanceLog.fromJson(data['data']['maintenanceLog']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du log de maintenance');
      }
    } catch (e) {
      debugPrint('Erreur getMaintenanceLog: $e');
      rethrow;
    }
  }

  /// Modifier un log de maintenance (avec fichier optionnel)
  Future<MaintenanceLog> updateMaintenanceLog(
    String vehicleId,
    String logId,
    Map<String, dynamic> payload, {
    PlatformFile? file,
    String? filePath,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/logs/$logId');

      // Si un fichier est fourni, utiliser multipart
      if (file != null) {
        final request = http.MultipartRequest('PATCH', uri);
        final token = await _storage.read(key: 'token');
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        // Ajouter les champs du payload
        payload.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        // Ajouter le fichier
        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes(
            'document',
            file.bytes!,
            filename: file.name,
          ));
        } else if (filePath != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'document',
            filePath,
            filename: file.name,
          ));
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data']['maintenanceLog'] != null) {
            return MaintenanceLog.fromJson(data['data']['maintenanceLog']);
          }
          throw Exception('Format de réponse invalide');
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du log de maintenance');
        }
      } else {
        // Pas de fichier, utiliser JSON classique
        final headers = await _getHeaders();
        
        final response = await _makeRequest(
          () => http.patch(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          ),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data']['maintenanceLog'] != null) {
            return MaintenanceLog.fromJson(data['data']['maintenanceLog']);
          }
          throw Exception('Format de réponse invalide');
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du log de maintenance');
        }
      }
    } catch (e) {
      debugPrint('Erreur updateMaintenanceLog: $e');
      rethrow;
    }
  }

  /// Supprimer un log de maintenance
  Future<void> deleteMaintenanceLog(
    String vehicleId,
    String logId,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/logs/$logId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.delete(uri, headers: headers),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du log de maintenance');
      }
    } catch (e) {
      debugPrint('Erreur deleteMaintenanceLog: $e');
      rethrow;
    }
  }

  /// Liste paginée des logs de maintenance
  Future<Map<String, dynamic>> listMaintenanceLogs(
    String vehicleId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/maintenance/logs')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final logs = (data['data']['maintenanceLogs'] as List)
              .map((log) => MaintenanceLog.fromJson(log))
              .toList();
          return {
            'maintenanceLogs': logs,
            'pagination': data['data']['pagination'],
          };
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des logs de maintenance');
      }
    } catch (e) {
      debugPrint('Erreur listMaintenanceLogs: $e');
      rethrow;
    }
  }

  /// Créer un document pour un véhicule (avec fichier uploadé ou URL)
  Future<VehicleDocument> createDocument(
    String vehicleId,
    Map<String, dynamic> payload, {
    PlatformFile? file,
    String? filePath,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/documents');

      // Si un fichier est fourni, utiliser multipart/form-data
      if (file != null || filePath != null) {
        final request = http.MultipartRequest('POST', uri);
        
        // Ajouter les headers (sans Content-Type, multer le gère)
        final token = await _storage.read(key: 'token');
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        // Ajouter les champs du formulaire
        request.fields['type'] = payload['type'] as String;
        request.fields['label'] = payload['label'] as String;
        request.fields['date'] = payload['date'] as String;
        if (payload['notes'] != null) {
          request.fields['notes'] = payload['notes'] as String;
        }

        // Ajouter le fichier
        if (kIsWeb && file != null && file.bytes != null) {
          // Web: utiliser les bytes
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (!kIsWeb && filePath != null) {
          // Mobile/Desktop: utiliser le chemin
          request.files.add(
            await http.MultipartFile.fromPath('file', filePath),
          );
        } else if (file != null && file.path != null) {
          // Fallback: utiliser le path si disponible
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path!),
          );
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data']['document'] != null) {
            return VehicleDocument.fromJson(data['data']['document']);
          }
          throw Exception('Format de réponse invalide');
        } else {
          final errorData = jsonDecode(response.body);
          debugPrint('[GarageService] createDocument error: ${response.statusCode}, ${response.body}');
          throw Exception(errorData['message'] ?? 'Erreur lors de la création du document');
        }
      } else {
        // Pas de fichier: utiliser JSON avec fileUrl (compatibilité)
        final headers = await _getHeaders();
        
        final response = await _makeRequest(
          () => http.post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          ),
        );

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null && data['data']['document'] != null) {
            return VehicleDocument.fromJson(data['data']['document']);
          }
          throw Exception('Format de réponse invalide');
        } else {
          final errorData = jsonDecode(response.body);
          debugPrint('[GarageService] createDocument error: ${response.statusCode}, ${response.body}');
          throw Exception(errorData['message'] ?? 'Erreur lors de la création du document');
        }
      }
    } catch (e) {
      debugPrint('Erreur createDocument: $e');
      rethrow;
    }
  }

  /// Liste paginée des documents d'un véhicule
  Future<Map<String, dynamic>> listDocuments(
    String vehicleId, {
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/documents')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final documents = (data['data']['documents'] as List)
              .map((doc) => VehicleDocument.fromJson(doc))
              .toList();
          return {
            'documents': documents,
            'pagination': data['data']['pagination'],
          };
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des documents');
      }
    } catch (e) {
      debugPrint('Erreur listDocuments: $e');
      rethrow;
    }
  }

  /// Récupérer un document
  Future<VehicleDocument> getDocument(String vehicleId, String documentId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/documents/$documentId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['document'] != null) {
          return VehicleDocument.fromJson(data['data']['document']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération du document');
      }
    } catch (e) {
      debugPrint('Erreur getDocument: $e');
      rethrow;
    }
  }

  /// Mettre à jour un document
  Future<VehicleDocument> updateDocument(
    String vehicleId,
    String documentId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/documents/$documentId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.patch(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['document'] != null) {
          return VehicleDocument.fromJson(data['data']['document']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la mise à jour du document');
      }
    } catch (e) {
      debugPrint('Erreur updateDocument: $e');
      rethrow;
    }
  }

  /// Supprimer un document
  Future<void> deleteDocument(String vehicleId, String documentId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/documents/$documentId');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.delete(uri, headers: headers),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du document');
      }
    } catch (e) {
      debugPrint('Erreur deleteDocument: $e');
      rethrow;
    }
  }

  /// Ajouter plusieurs photos à la galerie d'un véhicule
  Future<Vehicle> addVehiclePhotos(
    String vehicleId,
    List<XFile> photos,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/photos');

      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Ajouter chaque photo
      for (final photo in photos) {
        if (kIsWeb) {
          // Web: utiliser les bytes
          final bytes = await photo.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'photos',
              bytes,
              filename: photo.name,
            ),
          );
        } else {
          // Mobile/Desktop: utiliser le chemin
          request.files.add(
            await http.MultipartFile.fromPath('photos', photo.path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['vehicle'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('[GarageService] addVehiclePhotos error: ${response.statusCode}, ${response.body}');
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'ajout des photos');
      }
    } catch (e) {
      debugPrint('Erreur addVehiclePhotos: $e');
      rethrow;
    }
  }

  /// Lister les photos d'un véhicule avec pagination
  Future<Map<String, dynamic>> listVehiclePhotos(
    String vehicleId, {
    int page = 1,
    int limit = 24,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/photos')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

      final headers = await _getHeaders();

      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final items = (data['data']['items'] as List)
              .map((p) => VehiclePhoto.fromJson(p))
              .toList();
          final pagination = data['data']['pagination'] as Map<String, dynamic>;
          
          return {
            'items': items,
            'page': pagination['page'] as int,
            'limit': pagination['limit'] as int,
            'total': pagination['total'] as int,
            'hasMore': pagination['hasMore'] as bool,
          };
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du chargement des photos');
      }
    } catch (e) {
      debugPrint('Erreur listVehiclePhotos: $e');
      rethrow;
    }
  }

  /// Supprimer une photo de la galerie
  Future<Vehicle> deleteVehiclePhoto(String vehicleId, int photoIndex) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vehicles/$vehicleId/photos/$photoIndex');

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.delete(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['vehicle'] != null) {
          return Vehicle.fromJson(data['data']['vehicle']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la suppression de la photo');
      }
    } catch (e) {
      debugPrint('Erreur deleteVehiclePhoto: $e');
      rethrow;
    }
  }

  /// Rechercher les marques via vPIC
  Future<List<Map<String, dynamic>>> searchMakes({String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vpic/makes')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['makes'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['makes']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la recherche de marques');
      }
    } catch (e) {
      debugPrint('Erreur searchMakes: $e');
      rethrow;
    }
  }

  /// Récupérer les modèles pour une marque via vPIC
  Future<List<Map<String, dynamic>>> getModelsForMake(
    String makeName, {
    int? year,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (year != null) {
        queryParams['year'] = year.toString();
      }

      final encodedMakeName = Uri.encodeComponent(makeName);
      final uri = Uri.parse('${ApiConfig.apiUrl}$basePath/vpic/makes/$encodedMakeName/models')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      
      final response = await _makeRequest(
        () => http.get(uri, headers: headers),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['models'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['models']);
        }
        throw Exception('Format de réponse invalide');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des modèles');
      }
    } catch (e) {
      debugPrint('Erreur getModelsForMake: $e');
      rethrow;
    }
  }
}
