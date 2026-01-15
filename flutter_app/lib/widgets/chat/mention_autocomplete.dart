import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_suggestion.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

/// Widget d'autocomplete pour les mentions @pseudo
class MentionAutocomplete extends StatefulWidget {
  final String groupId;
  final String query; // Le texte après le @
  final Function(UserSuggestion) onSelect;
  final VoidCallback onDismiss;

  const MentionAutocomplete({
    super.key,
    required this.groupId,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  final ApiService _apiService = ApiService();
  List<UserSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeToken();
  }

  Future<void> _initializeToken() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      if (token != null) {
        _apiService.setToken(token);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation du token: $e');
    }
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(MentionAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _loadSuggestions();
    }
  }

  Future<void> _ensureToken() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      if (token != null) {
        _apiService.setToken(token);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération du token: $e');
    }
  }

  Future<void> _loadSuggestions() async {
    if (widget.query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    // S'assurer que le token est défini
    await _ensureToken();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _apiService.suggestGroupMembers(widget.groupId, widget.query);
      if (mounted) {
        setState(() {
          _suggestions = results.map((json) => UserSuggestion.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _suggestions = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Text(
          'Erreur: $_error',
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Text(
          'Aucun membre trouvé',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: suggestion.avatarUrl != null
                  ? NetworkImage(suggestion.avatarUrl!)
                  : null,
              child: suggestion.avatarUrl == null
                  ? Text(
                      suggestion.displayName.isNotEmpty
                          ? suggestion.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    )
                  : null,
            ),
            title: Text(
              suggestion.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            subtitle: suggestion.username != suggestion.displayName
                ? Text(
                    '@${suggestion.username}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  )
                : null,
            onTap: () {
              widget.onSelect(suggestion);
            },
          );
        },
      ),
    );
  }
}

