// Stub pour dart:io sur le web
// Ce fichier est utilisé quand dart:io n'est pas disponible (web)

class File {
  final String path;
  File(this.path);
  Future<void> writeAsString(String content) {
    throw UnsupportedError('File.writeAsString is not available on web');
  }
  Future<void> writeAsBytes(List<int> bytes) {
    throw UnsupportedError('File.writeAsBytes is not available on web');
  }
}

