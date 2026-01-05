import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Conditions Générales d\'Utilisation'),
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
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
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
                      Icons.gavel_rounded,
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
                          'CGU RideTogether',
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
              '1. Objet',
              'Les présentes Conditions Générales d\'Utilisation (CGU) régissent l\'utilisation de l\'application mobile RideTogether, développée pour permettre aux utilisateurs d\'organiser et de participer à des balades en moto ou en voiture.',
            ),
            _buildSection(
              context,
              '2. Acceptation des CGU',
              'L\'utilisation de l\'application RideTogether implique l\'acceptation pleine et entière des présentes CGU. Si vous n\'acceptez pas ces conditions, vous ne devez pas utiliser l\'application.',
            ),
            _buildSection(
              context,
              '3. Inscription et compte utilisateur',
              'Pour utiliser l\'application, vous devez créer un compte en fournissant des informations exactes et à jour. Vous êtes responsable de la confidentialité de vos identifiants et de toutes les activités effectuées sous votre compte.',
            ),
            _buildSection(
              context,
              '4. Utilisation de l\'application',
              'Vous vous engagez à utiliser l\'application de manière conforme à la loi et aux présentes CGU. Il est interdit de :\n\n'
              '• Publier du contenu illégal, offensant ou diffamatoire\n'
              '• Utiliser l\'application à des fins commerciales non autorisées\n'
              '• Tenter d\'accéder de manière non autorisée aux systèmes de l\'application\n'
              '• Utiliser des robots ou scripts automatisés\n'
              '• Violer les droits de propriété intellectuelle',
            ),
            _buildSection(
              context,
              '5. Organisation et participation aux balades',
              'Les organisateurs de balades sont responsables de la sécurité et du bon déroulement de leurs événements. RideTogether ne peut être tenu responsable des accidents, dommages ou incidents survenant lors des balades. Les participants s\'engagent à respecter le code de la route et à avoir les documents nécessaires (permis, assurance, etc.).',
            ),
            _buildSection(
              context,
              '6. Contenu utilisateur',
              'En publiant du contenu sur l\'application (photos, messages, commentaires), vous accordez à RideTogether une licence non exclusive pour utiliser, modifier et afficher ce contenu dans le cadre de l\'application. Vous garantissez que vous disposez des droits nécessaires sur ce contenu.',
            ),
            _buildSection(
              context,
              '7. Propriété intellectuelle',
              'L\'application RideTogether, son design, ses logos et son contenu sont protégés par les lois sur la propriété intellectuelle. Toute reproduction non autorisée est interdite.',
            ),
            _buildSection(
              context,
              '8. Données personnelles',
              'Le traitement de vos données personnelles est décrit dans notre Politique de Confidentialité, que vous acceptez en utilisant l\'application.',
            ),
            _buildSection(
              context,
              '9. Limitation de responsabilité',
              'RideTogether est fourni "en l\'état". Nous ne garantissons pas que l\'application sera exempte d\'erreurs ou de dysfonctionnements. Nous ne pourrons être tenus responsables des dommages directs ou indirects résultant de l\'utilisation de l\'application.',
            ),
            _buildSection(
              context,
              '10. Modification des CGU',
              'RideTogether se réserve le droit de modifier les présentes CGU à tout moment. Les modifications entrent en vigueur dès leur publication. Il est recommandé de consulter régulièrement cette page.',
            ),
            _buildSection(
              context,
              '11. Résiliation',
              'Nous nous réservons le droit de suspendre ou de résilier votre compte en cas de violation des présentes CGU, sans préavis ni remboursement.',
            ),
            _buildSection(
              context,
              '12. Droit applicable et juridiction',
              'Les présentes CGU sont régies par le droit français. En cas de litige, les tribunaux français seront seuls compétents.',
            ),
            _buildSection(
              context,
              '13. Contact',
              'Pour toute question concernant les CGU, vous pouvez nous contacter à l\'adresse suivante : contact@ridetogether.fr',
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
                    AppTheme.primaryColor.withOpacity(0.08),
                    AppTheme.secondaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'En utilisant RideTogether, vous reconnaissez avoir lu, compris et accepté les présentes Conditions Générales d\'Utilisation.',
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
            color: AppTheme.primaryColor.withOpacity(0.1),
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
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
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
                      color: AppTheme.primaryColor,
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

