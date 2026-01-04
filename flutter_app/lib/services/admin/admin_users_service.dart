import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../config/api_config.dart';
import '../api_service.dart';
import '../../models/admin/admin_user.dart';

class AdminUsersService {
  final ApiService _apiService;

  AdminUsersService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Récupère la liste des utilisateurs avec pagination et recherche
  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 50,
    String? query,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }

      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/users')
          .replace(queryParameters: queryParams);

      debugPrint('[AdminUsersService] GET $uri');

      final response = await _apiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usersList = (data['data']?['users'] as List<dynamic>?)
                ?.map((json) => AdminUser.fromJson(json))
                .toList() ??
            [];

        return {
          'users': usersList,
          'pagination': data['data']?['pagination'] ?? {},
        };
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminUsersService] Erreur getUsers: $e');
      rethrow;
    }
  }

  /// Crée un utilisateur
  Future<AdminUser> createUser({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/users');

      final body = jsonEncode({
        'email': email,
        'password': password,
        'role': role,
      });

      debugPrint('[AdminUsersService] POST $uri');

      final response = await _apiService.post(uri, body: body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AdminUser.fromJson(data['data']?['user'] ?? data['data'] ?? {});
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminUsersService] Erreur createUser: $e');
      rethrow;
    }
  }

  /// Met à jour un utilisateur
  Future<AdminUser> updateUser(
    String userId, {
    String? email,
    String? role,
    String? password,
    bool? banned,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/users/$userId');

      final body = <String, dynamic>{};
      if (email != null) body['email'] = email;
      if (role != null) body['role'] = role;
      if (password != null) body['password'] = password;
      if (banned != null) body['banned'] = banned;

      debugPrint('[AdminUsersService] PATCH $uri');

      final response = await _apiService.patch(
        uri,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AdminUser.fromJson(data['data']?['user'] ?? data['data'] ?? {});
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminUsersService] Erreur updateUser: $e');
      rethrow;
    }
  }

  /// Supprime un utilisateur
  Future<void> deleteUser(String userId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiUrl}/admin/users/$userId');

      debugPrint('[AdminUsersService] DELETE $uri');

      final response = await _apiService.delete(uri);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[AdminUsersService] Erreur deleteUser: $e');
      rethrow;
    }
  }
}

