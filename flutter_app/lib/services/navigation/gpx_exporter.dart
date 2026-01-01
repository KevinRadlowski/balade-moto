import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/waypoint.dart';
import 'navigation_service.dart';

/// Service pour exporter des itinéraires au format GPX
class GPXExporter {
  /// Génère le contenu GPX pour un itinéraire
  String generateGPX(NavigationRoute route, {String? name}) {
    final routeName = name ?? 'Itinéraire de balade';
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Balades Moto App" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>$routeName</name>');
    buffer.writeln('    <time>$timestamp</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <rte>');
    buffer.writeln('    <name>$routeName</name>');
    
    // Ajouter tous les waypoints dans l'ordre
    final allWaypoints = route.allWaypoints;
    for (var i = 0; i < allWaypoints.length; i++) {
      final wp = allWaypoints[i];
      final wpName = _getWaypointName(wp, i, allWaypoints.length);
      
      buffer.writeln('    <rtept lat="${wp.latitude}" lon="${wp.longitude}">');
      buffer.writeln('      <name>$wpName</name>');
      if (wp.address.isNotEmpty) {
        buffer.writeln('      <desc>${_escapeXml(wp.address)}</desc>');
      }
      buffer.writeln('    </rtept>');
    }
    
    buffer.writeln('  </rte>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Génère un nom pour un waypoint
  String _getWaypointName(Waypoint wp, int index, int total) {
    switch (wp.type) {
      case 'depart':
        return 'Départ';
      case 'arrivee':
        return 'Arrivée';
      case 'checkpoint':
        return 'Point ${index}';
      default:
        return 'Point ${index + 1}';
    }
  }

  /// Échappe les caractères XML spéciaux
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Sauvegarde le GPX dans un fichier temporaire et le partage
  Future<void> shareGPX(NavigationRoute route, {String? name}) async {
    try {
      final gpxContent = generateGPX(route, name: name);
      final fileName = '${name ?? 'itineraire'}_${DateTime.now().millisecondsSinceEpoch}.gpx';
      
      // Obtenir le répertoire temporaire
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      
      // Écrire le contenu GPX
      await file.writeAsString(gpxContent);
      
      // Partager le fichier
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Partager l\'itinéraire GPX',
        subject: name ?? 'Itinéraire de balade',
      );
    } catch (e) {
      throw Exception('Erreur lors de l\'export GPX: $e');
    }
  }

  /// Sauvegarde le GPX dans un fichier et retourne le chemin
  Future<String> saveGPX(NavigationRoute route, {String? name}) async {
    try {
      final gpxContent = generateGPX(route, name: name);
      final fileName = '${name ?? 'itineraire'}_${DateTime.now().millisecondsSinceEpoch}.gpx';
      
      // Obtenir le répertoire de documents
      final documentsDir = await getApplicationDocumentsDirectory();
      final file = File('${documentsDir.path}/$fileName');
      
      // Écrire le contenu GPX
      await file.writeAsString(gpxContent);
      
      return file.path;
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde GPX: $e');
    }
  }
}


