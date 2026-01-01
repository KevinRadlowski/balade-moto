import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/vehicle_icon_helper.dart';

class AttachmentMenu extends StatelessWidget {
  final VoidCallback? onDocument;
  final VoidCallback? onPhotoVideo;
  final VoidCallback? onCamera;
  final VoidCallback? onAudio;
  final VoidCallback? onPoll;
  final VoidCallback? onRide;

  const AttachmentMenu({
    super.key,
    this.onDocument,
    this.onPhotoVideo,
    this.onCamera,
    this.onAudio,
    this.onPoll,
    this.onRide,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final vehiclePreference = authService.user?.vehiclePreference;
    final rideIcon = getVehicleIcon(vehiclePreference);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ligne 1 : Document, Photo/Video, Caméra
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: onDocument,
                ),
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Photo/Video',
                  color: Colors.purple,
                  onTap: onPhotoVideo,
                ),
                _AttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  color: Colors.grey,
                  onTap: onCamera,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ligne 2 : Audio, Sondage, Balade
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.mic,
                  label: 'Audio',
                  color: Colors.orange,
                  onTap: onAudio,
                ),
                _AttachmentOption(
                  icon: Icons.poll,
                  label: 'Sondage',
                  color: Colors.green,
                  onTap: onPoll,
                ),
                _AttachmentOption(
                  icon: rideIcon,
                  label: 'Balade',
                  color: Colors.red,
                  onTap: onRide,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

