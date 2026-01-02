import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class SocialAuthButtons extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;
  final VoidCallback? onFacebookPressed;
  final bool isLoading;

  const SocialAuthButtons({
    super.key,
    this.onGooglePressed,
    this.onApplePressed,
    this.onFacebookPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google
        if (onGooglePressed != null)
          _SocialButton(
            icon: Icons.g_mobiledata,
            label: 'Continuer avec Google',
            backgroundColor: Colors.white,
            textColor: Colors.grey.shade800,
            borderColor: Colors.grey.shade300,
            onPressed: isLoading ? null : onGooglePressed,
            iconColor: const Color(0xFF4285F4),
          ),
        
        // Apple (uniquement iOS/macOS, pas sur web)
        if (onApplePressed != null && !kIsWeb) ...[
          const SizedBox(height: 12),
          _SocialButton(
            icon: Icons.apple,
            label: 'Continuer avec Apple',
            backgroundColor: Colors.black,
            textColor: Colors.white,
            borderColor: Colors.black,
            onPressed: isLoading ? null : onApplePressed,
            iconColor: Colors.white,
          ),
        ],
        
        // Facebook
        if (onFacebookPressed != null) ...[
          const SizedBox(height: 12),
          _SocialButton(
            icon: Icons.facebook,
            label: 'Continuer avec Facebook',
            backgroundColor: const Color(0xFF1877F2),
            textColor: Colors.white,
            borderColor: const Color(0xFF1877F2),
            onPressed: isLoading ? null : onFacebookPressed,
            iconColor: Colors.white,
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.iconColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 24),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

