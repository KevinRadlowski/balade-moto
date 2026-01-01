import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class ChatService {
  final ApiService _apiService;
  final String baseUrl;
  String? _token;

  ChatService({
    ApiService? apiService,
    String? baseUrl,
  })  : _apiService = apiService ?? ApiService(),
        baseUrl = baseUrl ?? ApiConfig.apiBaseUrl;

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<void> setToken(String? token) async {
    _token = token;
    _apiService.setToken(token);
  }

  // Obtenir les messages avec pagination
  Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    required String type, // 'group' ou 'ride'
    String? cursor,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/api/messages/$type/$conversationId')
        .replace(queryParameters: {
      if (cursor != null) 'cursor': cursor,
      'limit': limit.toString(),
    });

    final response = await http.get(
      uri,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la récupération des messages');
    }
  }

  // Envoyer un message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String type,
    required String content,
    String? replyToMessageId,
    String messageType = 'text',
    Map<String, dynamic>? pollData,
    String? proposedRideId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages'),
      headers: _headers,
      body: jsonEncode({
        'conversationId': conversationId,
        'type': type,
        'content': content,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        'messageType': messageType,
        if (pollData != null) 'pollData': pollData,
        if (proposedRideId != null) 'proposedRideId': proposedRideId,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du message');
    }
  }

  // Proposer une balade dans un groupe (crée automatiquement un sondage)
  Future<Map<String, dynamic>> proposeRide({
    required String conversationId,
    required String type,
    required String rideId,
    String? content,
  }) async {
    return await sendMessage(
      conversationId: conversationId,
      type: type,
      content: content ?? 'Je propose cette balade !',
      messageType: 'ride',
      proposedRideId: rideId,
    );
  }

  // Voter sur un sondage
  Future<Map<String, dynamic>> votePoll({
    required String messageId,
    required int optionIndex,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages/$messageId/poll/vote'),
      headers: _headers,
      body: jsonEncode({
        'optionIndex': optionIndex,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors du vote');
    }
  }

  // Envoyer un message avec fichier (utilise path - pour mobile/desktop)
  Future<Map<String, dynamic>> sendMessageWithFile({
    required String conversationId,
    required String type,
    required String filePath,
    required String fileType, // 'image', 'video', 'audio', 'file'
    String? content,
    String? replyToMessageId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/messages'),
    );

    // Ajouter le token d'authentification
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    // Ajouter les champs
    request.fields['conversationId'] = conversationId;
    request.fields['type'] = type; // 'group' ou 'ride'
    request.fields['messageType'] = fileType; // Le type de fichier: 'image', 'video', 'audio', 'file'
    if (content != null && content.isNotEmpty) {
      request.fields['content'] = content;
    }
    if (replyToMessageId != null) {
      request.fields['replyToMessageId'] = replyToMessageId;
    }

    // Ajouter le fichier
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du fichier');
    }
  }

  // Envoyer un message avec fichier (utilise bytes - pour web)
  Future<Map<String, dynamic>> uploadFile({
    required String conversationId,
    required String type,
    required dynamic file, // PlatformFile ou XFile
    required String messageType, // 'image', 'video', 'audio', 'file'
    String? replyToMessageId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/messages'),
    );

    // Ajouter le token d'authentification
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    // Ajouter les champs
    request.fields['conversationId'] = conversationId;
    request.fields['type'] = type; // 'group' ou 'ride'
    request.fields['messageType'] = messageType;
    // Pour les fichiers, envoyer le nom du fichier comme contenu (requis par le modèle)
    String fileContent = '';
    if (file is PlatformFile) {
      fileContent = file.name.isNotEmpty ? file.name : 'Fichier';
    } else if (file is XFile) {
      fileContent = file.name.isNotEmpty ? file.name : 'Fichier';
    }
    request.fields['content'] = fileContent;
    if (replyToMessageId != null) {
      request.fields['replyToMessageId'] = replyToMessageId;
    }

    // Récupérer les bytes et le nom du fichier
    Uint8List bytes;
    String fileName;

    try {
      if (file is PlatformFile) {
        if (file.bytes == null) {
          throw Exception('Impossible de lire le fichier (bytes null). Nom: ${file.name}, Taille: ${file.size}');
        }
        if (file.bytes!.isEmpty) {
          throw Exception('Le fichier est vide. Nom: ${file.name}');
        }
        bytes = file.bytes!;
        fileName = file.name.isNotEmpty ? file.name : 'fichier';
      } else if (file is XFile) {
        bytes = await file.readAsBytes();
        fileName = file.name.isNotEmpty ? file.name : 'fichier';
      } else {
        // Essayer de convertir en PlatformFile si possible
        throw Exception('Type de fichier non supporté: ${file.runtimeType}. Types supportés: PlatformFile, XFile');
      }
    } catch (e) {
      // Améliorer le message d'erreur pour le débogage
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Erreur lors de la lecture du fichier: $e');
    }

    // Ajouter le fichier avec bytes
    // Le nom de fichier sera automatiquement encodé en UTF-8 par http.MultipartFile
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'envoi du fichier');
    }
  }

  // Modifier un message
  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String content,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/messages/$messageId'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la modification du message');
    }
  }

  // Supprimer un message
  Future<Map<String, dynamic>> deleteMessage({
    required String messageId,
    String scope = 'me', // 'me' ou 'all'
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/messages/$messageId?scope=$scope'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la suppression du message');
    }
  }

  // Restaurer un message supprimé "pour moi"
  Future<Map<String, dynamic>> restoreMessage({
    required String messageId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages/$messageId/restore'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la restauration du message');
    }
  }

  // Toggle réaction
  Future<Map<String, dynamic>> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages/$messageId/reactions'),
      headers: _headers,
      body: jsonEncode({
        'emoji': emoji,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de la réaction');
    }
  }

  // Épingler/Désépingler un message
  Future<Map<String, dynamic>> togglePin({
    required String messageId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages/$messageId/pin'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Erreur lors de l\'épinglage du message');
    }
  }

  // Marquer comme lu
  Future<void> markAsRead({
    required String conversationId,
    required String type,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/api/messages/$type/$conversationId/read'),
      headers: _headers,
    );
  }
}

