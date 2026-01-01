import 'package:flutter/material.dart';
import 'star_rating.dart';

/// Formulaire de notation avec étoiles et commentaire
class RatingForm extends StatefulWidget {
  final Function(int rating, String? comment) onSubmit;
  final bool isLoading;

  const RatingForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<RatingForm> createState() => _RatingFormState();
}

class _RatingFormState extends State<RatingForm> with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une note'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _hasSubmitted = true;
    });

    _animationController.forward().then((_) {
      widget.onSubmit(
        _selectedRating,
        _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _hasSubmitted ? _scaleAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star_rate_rounded,
                      color: Colors.amber.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Noter cette balade',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: StarRating(
                    rating: _selectedRating,
                    size: 40,
                    interactive: !widget.isLoading && !_hasSubmitted,
                    onRatingChanged: (rating) {
                      setState(() {
                        _selectedRating = rating;
                      });
                    },
                  ),
                ),
                if (_selectedRating > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '$_selectedRating / 5',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _commentController,
                  enabled: !widget.isLoading && !_hasSubmitted,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: 'Commentaire (optionnel)',
                    hintText: 'Partagez votre expérience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (widget.isLoading || _hasSubmitted || _selectedRating == 0)
                        ? null
                        : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _hasSubmitted ? 'Note envoyée !' : 'Envoyer ma note',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



