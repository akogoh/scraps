import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP client for mobile/desktop that can relax certificates for mNotify
/// while still using the normal security model elsewhere.
http.Client createHttpClient() {
  final client = HttpClient();
  client.badCertificateCallback =
      (X509Certificate cert, String host, int port) {
    return host == 'api.mnotify.com';
  };
  return IOClient(client);
}

