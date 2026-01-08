import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/ride.dart';
import '../../services/api_service.dart';
import '../../constants/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../config/api_config.dart';
import '../../providers/plan_provider.dart';
import '../../screens/premium/premium_screen.dart';

// Imports conditionnels
import 'dart:io' if (dart.library.html) 'dart_io_stub.dart' show File;
import 'dart:html' as html if (dart.library.io) 'dart_html_stub.dart';
// Import path_provider uniquement sur mobile (pas web)
// Le stub est utilisé sur le web, mais le code web n'utilisera jamais cette fonction
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'path_provider_stub.dart' show getApplicationDocumentsDirectory;

/// Section "Fonctions avancées" pour les balades
/// Affiche les 4 fonctionnalités : Export GPX, Export PDF, Partage externe,
/// Mode balade privée secrète
class AdvancedFeaturesSection extends StatefulWidget {
  final Ride ride;
  final ApiService apiService;
  final VoidCallback? onRideUpdated;

  const AdvancedFeaturesSection({
    super.key,
    required this.ride,
    required this.apiService,
    this.onRideUpdated,
  });

  @override
  State<AdvancedFeaturesSection> createState() => _AdvancedFeaturesSectionState();
}

class _AdvancedFeaturesSectionState extends State<AdvancedFeaturesSection> {
  bool _isExpanded = false;
  bool _isExportingGPX = false;
  bool _isExportingPDF = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header avec toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Fonctions avancées',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Contenu expandable
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<PlanProvider>(
                builder: (context, planProvider, child) {
                  final isPremium = planProvider.isPremium;
                  
                  if (!isPremium) {
                    // Afficher un message premium pour les utilisateurs non premium
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.orange.shade700,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Fonctionnalités Premium',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Les fonctions avancées sont réservées aux membres premium.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const PremiumScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.star),
                                label: const Text('Passer à Premium'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  
                  // Contenu pour les membres premium
                  return Column(
                    children: [
                      // 1. Export GPX
                      _buildFeatureItem(
                        icon: Icons.map_outlined,
                        title: 'Export GPX',
                        subtitle: 'Télécharge le tracé de tes balades au format GPX',
                        onTap: _exportGPX,
                        isLoading: _isExportingGPX,
                      ),

                      const Divider(height: 24),

                      // 2. Export PDF
                      _buildFeatureItem(
                        icon: Icons.picture_as_pdf,
                        title: 'Export PDF',
                        subtitle: 'Génère un PDF détaillé de tes balades',
                        onTap: _exportPDF,
                        isLoading: _isExportingPDF,
                      ),

                      const Divider(height: 24),

                      // 3. Partage externe
                      _buildFeatureItem(
                        icon: Icons.share,
                        title: 'Partage externe',
                        subtitle: 'Partage tes balades sur WhatsApp, Maps et autres apps',
                        onTap: _shareRide,
                      ),

                      const Divider(height: 24),

                      // 4. Mode "balade privée secrète"
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFeatureItem(
                            icon: Icons.lock_outline,
                            title: 'Mode "balade privée secrète"',
                            subtitle: 'Crée des balades invisibles, accessibles uniquement par lien',
                            onTap: _toggleSecretMode,
                            trailing: widget.ride.visibilite == 'secrete' 
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'ACTIF',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          if (widget.ride.visibilite == 'secrete' && widget.ride.secretLink != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.link, size: 16, color: Colors.orange.shade800),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lien secret:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    _getFullSecretLink(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _copySecretLink(),
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('Copier le lien'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : Icon(icon, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportGPX() async {
    setState(() => _isExportingGPX = true);

    try {
      if (kIsWeb) {
        // Sur le web, utiliser le service API puis créer un blob pour télécharger
        final gpxContent = await widget.apiService.exportRideGPX(widget.ride.id);
        final bytes = utf8.encode(gpxContent);
        final blob = html.Blob([bytes], 'application/gpx+xml');
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: objectUrl)
          ..setAttribute('download', 'balade_${widget.ride.id}.gpx')
          ..click();
        html.Url.revokeObjectUrl(objectUrl);
        
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Fichier GPX téléchargé');
        }
      } else {
        // Sur mobile, utiliser le service API
        final gpxContent = await widget.apiService.exportRideGPX(widget.ride.id);
        
        // Sauvegarder et partager
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'balade_${widget.ride.id}_${DateTime.now().millisecondsSinceEpoch}.gpx';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(gpxContent);
        
        if (mounted) {
          // Partager le fichier
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Tracé GPX de la balade: ${widget.ride.titre}',
          );
          SnackBarHelper.showSuccess(context, 'Fichier GPX généré et partagé');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingGPX = false);
      }
    }
  }

  Future<void> _exportPDF() async {
    setState(() => _isExportingPDF = true);

    try {
      final pdfBytes = await widget.apiService.exportRidePDF(widget.ride.id);
      
      if (kIsWeb) {
        // Sur le web, utiliser le service API puis créer un blob pour télécharger
        final pdfBytes = await widget.apiService.exportRidePDF(widget.ride.id);
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: objectUrl)
          ..setAttribute('download', 'balade_${widget.ride.id}.pdf')
          ..click();
        html.Url.revokeObjectUrl(objectUrl);
        
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'PDF téléchargé');
        }
      } else {
        // Sur mobile, sauvegarder et partager
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'balade_${widget.ride.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        
        if (mounted) {
          // Partager le fichier
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'PDF de la balade: ${widget.ride.titre}',
          );
          SnackBarHelper.showSuccess(context, 'PDF généré et partagé');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPDF = false);
      }
    }
  }

  Future<void> _shareRide() async {
    try {
      final rideUrl = '${ApiConfig.apiBaseUrl}/rides/${widget.ride.id}';
      final shareText = '${widget.ride.titre}\n\n${widget.ride.description ?? ''}\n\n$rideUrl';

      await Share.share(
        shareText,
        subject: widget.ride.titre,
      );
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Erreur lors du partage');
      }
    }
  }

  Future<void> _toggleSecretMode() async {
    if (widget.ride.visibilite == 'secrete') {
      // Désactiver le mode secret
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Désactiver le mode secret'),
          content: const Text(
            'La balade redeviendra visible dans les recherches. Le lien secret restera valide mais la balade sera accessible normalement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Désactiver'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await widget.apiService.updateRideVisibility(widget.ride.id, 'privee');
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'Mode secret désactivé');
            widget.onRideUpdated?.call();
          }
        } catch (e) {
          if (mounted) {
            SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
          }
        }
      }
    } else {
      // Activer le mode secret
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activer le mode secret'),
          content: const Text(
            'La balade deviendra invisible dans les recherches. Seuls les utilisateurs avec le lien secret pourront y accéder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Activer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await widget.apiService.updateRideVisibility(widget.ride.id, 'secrete');
          if (mounted) {
            SnackBarHelper.showSuccess(context, 'Mode secret activé');
            widget.onRideUpdated?.call();
          }
        } catch (e) {
          if (mounted) {
            SnackBarHelper.showError(context, e.toString().replaceAll('Exception: ', ''));
          }
        }
      }
    }
  }

  String _getFullSecretLink() {
    if (widget.ride.secretLink == null) return '';
    // Si c'est déjà une URL complète, la retourner telle quelle
    if (widget.ride.secretLink!.startsWith('http')) {
      return widget.ride.secretLink!;
    }
    // Sinon, construire l'URL complète
    return '${ApiConfig.apiBaseUrl}/rides/secret/${widget.ride.secretLink!}';
  }

  Future<void> _copySecretLink() async {
    if (widget.ride.secretLink != null) {
      await Clipboard.setData(ClipboardData(text: _getFullSecretLink()));
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Lien secret copié dans le presse-papiers');
      }
    }
  }
}

