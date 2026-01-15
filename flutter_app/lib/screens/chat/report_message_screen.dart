import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

/// Écran pour signaler un message
class ReportMessageScreen extends StatefulWidget {
  final String groupId;
  final String messageId;

  const ReportMessageScreen({
    super.key,
    required this.groupId,
    required this.messageId,
  });

  @override
  State<ReportMessageScreen> createState() => _ReportMessageScreenState();
}

class _ReportMessageScreenState extends State<ReportMessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _reasonTextController = TextEditingController();
  String? _selectedReasonCode;
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasonOptions = [
    {'code': 'SPAM', 'label': 'Spam'},
    {'code': 'HARASSMENT', 'label': 'Harcèlement'},
    {'code': 'HATE', 'label': 'Contenu haineux'},
    {'code': 'NUDITY', 'label': 'Contenu inapproprié'},
    {'code': 'OTHER', 'label': 'Autre'},
  ];

  Future<void> _submitReport() async {
    if (_selectedReasonCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une raison'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.storage.read(key: 'token');
      if (token != null) {
        _chatService.setToken(token);
      }

      await _chatService.reportMessage(
        groupId: widget.groupId,
        messageId: widget.messageId,
        reasonCode: _selectedReasonCode!,
        reasonText: _reasonTextController.text.trim().isEmpty
            ? null
            : _reasonTextController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message signalé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaler un message'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pourquoi signalez-vous ce message ?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._reasonOptions.map((option) => RadioListTile<String>(
                  title: Text(option['label']!),
                  value: option['code']!,
                  groupValue: _selectedReasonCode,
                  onChanged: (value) {
                    setState(() {
                      _selectedReasonCode = value;
                    });
                  },
                )),
            const SizedBox(height: 24),
            if (_selectedReasonCode == 'OTHER')
              TextField(
                controller: _reasonTextController,
                decoration: const InputDecoration(
                  labelText: 'Précisez la raison (optionnel)',
                  hintText: 'Décrivez le problème...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Signaler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

