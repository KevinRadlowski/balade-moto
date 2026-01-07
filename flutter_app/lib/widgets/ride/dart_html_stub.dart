// Stub pour dart:html sur mobile
// Ce fichier est utilisé quand dart:html n'est pas disponible (mobile)

class Blob {
  Blob(List<dynamic> data, String mimeType);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? href;
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}

