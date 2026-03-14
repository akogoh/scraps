import 'package:http/http.dart' as http;

/// Default HTTP client for platforms that don't support dart:io (e.g. web).
http.Client createHttpClient() => http.Client();

