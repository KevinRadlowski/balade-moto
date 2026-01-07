// Stub pour path_provider sur le web
// Ce fichier est utilisé quand path_provider n'est pas disponible (web)
// Les fonctions ne seront jamais appelées car le code web utilise html.Blob
// Ce stub existe uniquement pour satisfaire le compilateur

class Directory {
  final String path;
  Directory(this.path);
}

Future<Directory> getApplicationDocumentsDirectory() {
  throw UnsupportedError('getApplicationDocumentsDirectory should not be called on web');
}

