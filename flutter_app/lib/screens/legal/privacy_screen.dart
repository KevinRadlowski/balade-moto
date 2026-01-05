import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Politique de Confidentialité'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header premium
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.secondaryColor,
                    AppTheme.secondaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Politique de Confidentialité',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Dernière mise à jour : ${_getLastUpdateDate()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Contenu
            _buildSection(
              context,
              '1. Introduction',
              'RideTogether s\'engage à protéger votre vie privée et vos données personnelles. Cette politique de confidentialité explique comment nous collectons, utilisons, stockons et protégeons vos informations lorsque vous utilisez notre application.',
            ),
            _buildSection(
              context,
              '2. Données collectées',
              'Nous collectons les données suivantes :\n\n'
              '• Informations d\'identification : nom, prénom, email, pseudo\n'
              '• Données de profil : photo de profil, préférences de véhicule, avatars personnalisés\n'
              '• Données de localisation : coordonnées GPS pour les balades et la recherche géographique\n'
              '• Données d\'utilisation : historique des balades, messages, interactions\n'
              '• Données techniques : adresse IP, type d\'appareil, système d\'exploitation\n'
              '• Données de paiement : uniquement si des fonctionnalités payantes sont ajoutées (actuellement non applicable)',
            ),
            _buildSection(
              context,
              '3. Finalités du traitement',
              'Vos données sont utilisées pour :\n\n'
              '• Fournir et améliorer nos services\n'
              '• Gérer votre compte utilisateur\n'
              '• Organiser et gérer les balades\n'
              '• Faciliter la communication entre utilisateurs\n'
              '• Assurer la sécurité de l\'application\n'
              '• Respecter nos obligations légales\n'
              '• Envoyer des notifications importantes (avec votre consentement)',
            ),
            _buildSection(
              context,
              '4. Base légale du traitement',
              'Le traitement de vos données repose sur :\n\n'
              '• Votre consentement (pour les notifications, la géolocalisation)\n'
              '• L\'exécution d\'un contrat (utilisation de l\'application)\n'
              '• Nos intérêts légitimes (amélioration du service, sécurité)\n'
              '• Le respect d\'obligations légales',
            ),
            _buildSection(
              context,
              '5. Partage des données',
              'Nous ne vendons jamais vos données personnelles. Nous pouvons partager vos données uniquement dans les cas suivants :\n\n'
              '• Avec d\'autres utilisateurs de l\'application (profil public, messages dans les groupes)\n'
              '• Avec nos prestataires de services (hébergement, emails) sous contrat de confidentialité\n'
              '• Si requis par la loi ou une autorité judiciaire\n'
              '• En cas de fusion, acquisition ou cession d\'actifs (avec notification préalable)',
            ),
            _buildSection(
              context,
              '6. Conservation des données',
              'Nous conservons vos données personnelles :\n\n'
              '• Pendant toute la durée d\'utilisation de votre compte\n'
              '• Pendant 3 ans après la fermeture de votre compte (sauf obligation légale plus longue)\n'
              '• Les données de localisation sont supprimées après chaque utilisation, sauf si vous les avez enregistrées dans une balade',
            ),
            _buildSection(
              context,
              '7. Vos droits',
              'Conformément au RGPD, vous disposez des droits suivants :\n\n'
              '• Droit d\'accès : obtenir une copie de vos données\n'
              '• Droit de rectification : corriger vos données inexactes\n'
              '• Droit à l\'effacement : demander la suppression de vos données\n'
              '• Droit à la portabilité : récupérer vos données dans un format structuré\n'
              '• Droit d\'opposition : vous opposer au traitement de vos données\n'
              '• Droit à la limitation : limiter le traitement de vos données\n'
              '• Droit de retirer votre consentement à tout moment\n\n'
              'Pour exercer ces droits, contactez-nous à : contact@ridetogether.fr',
            ),
            _buildSection(
              context,
              '8. Sécurité des données',
              'Nous mettons en œuvre des mesures techniques et organisationnelles appropriées pour protéger vos données :\n\n'
              '• Chiffrement des données sensibles (mots de passe, tokens)\n'
              '• Authentification sécurisée (JWT, refresh tokens)\n'
              '• Accès restreint aux données personnelles\n'
              '• Sauvegardes régulières\n'
              '• Surveillance des accès et logs de sécurité',
            ),
            _buildSection(
              context,
              '9. Cookies et technologies similaires',
              'L\'application utilise des technologies similaires aux cookies pour :\n\n'
              '• Mémoriser vos préférences (authentification, thème)\n'
              '• Améliorer les performances\n'
              '• Analyser l\'utilisation de l\'application\n\n'
              'Vous pouvez gérer ces préférences dans les paramètres de votre appareil.',
            ),
            _buildSection(
              context,
              '10. Données de localisation',
              'L\'application nécessite l\'accès à votre localisation pour :\n\n'
              '• Rechercher des balades à proximité\n'
              '• Créer des itinéraires\n'
              '• Partager votre position lors des balades (avec votre consentement)\n\n'
              'Vous pouvez désactiver la géolocalisation à tout moment dans les paramètres de votre appareil.',
            ),
            _buildSection(
              context,
              '11. Transferts internationaux',
              'Vos données sont stockées sur des serveurs situés dans l\'Union Européenne. En cas de transfert hors UE, nous nous assurons que des garanties appropriées sont en place (clauses contractuelles types, Privacy Shield, etc.).',
            ),
            _buildSection(
              context,
              '12. Mineurs',
              'L\'application est destinée aux utilisateurs âgés de 18 ans et plus. Nous ne collectons pas sciemment de données personnelles de mineurs. Si vous êtes parent et pensez que votre enfant nous a fourni des données, contactez-nous immédiatement.',
            ),
            _buildSection(
              context,
              '13. Modifications de la politique',
              'Nous pouvons modifier cette politique de confidentialité à tout moment. Les modifications importantes vous seront notifiées via l\'application ou par email. La date de dernière mise à jour est indiquée en haut de ce document.',
            ),
            _buildSection(
              context,
              '14. Contact',
              'Pour toute question concernant cette politique de confidentialité ou l\'exercice de vos droits, contactez-nous :\n\n'
              'Email : contact@ridetogether.fr\n'
              'Adresse : [Adresse du siège social]\n'
              'Délégué à la Protection des Données : dpo@ridetogether.fr',
            ),
            
            const SizedBox(height: 32),
            
            // Footer premium
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.secondaryColor.withOpacity(0.08),
                    AppTheme.primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'En utilisant RideTogether, vous reconnaissez avoir lu et compris cette Politique de Confidentialité.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.secondaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.secondaryColor,
                        AppTheme.primaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.8,
                color: Colors.grey.shade800,
                fontSize: 15,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLastUpdateDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }
}

