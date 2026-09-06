import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../../shared/widgets/alert_popup.dart';
import '../constants/app_constants.dart';

class ApiService {
  final String baseUrl;
  String? _authToken;

  // Private constructor
  ApiService._internal(this.baseUrl);

  // Singleton instance
  static final ApiService _instance = ApiService._internal(
    AppConstants.baseUrl,
  );

  // Public getter for singleton
  static ApiService get instance => _instance;

  // Set the authentication token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Headers for authenticated requests
  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Map<String, String> get _defaultHeaders => {'Accept': 'application/json'};

  // Helper method to show error alerts
  void _showErrorAlert(String message, {String? title}) {
    AlertPopupManager().showAlert(
      message: message,
      title: title ?? 'Error',
      type: AlertType.error,
    );
  }

  // Helper method to extract error message from response
  String _extractErrorMessage(dynamic responseBody, String defaultMessage) {
    try {
      if (responseBody is String) {
        final decoded = json.decode(responseBody);
        if (decoded is Map) {
          // Check for direct message field first (like {"message":"Invalid credentials"})
          if (decoded.containsKey('message') && decoded['message'] is String) {
            return decoded['message'];
          }

          // Check for direct error field
          if (decoded.containsKey('error') && decoded['error'] is String) {
            return decoded['error'];
          }

          // Check for nested errors structure
          if (decoded.containsKey('errors') && decoded['errors'] is Map) {
            final errors = decoded['errors'] as Map;
            // Get first error message from the errors map
            if (errors.isNotEmpty) {
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                return firstError.first.toString();
              } else if (firstError is String) {
                return firstError;
              }
            }
          }

          // Fallback to any string value in the response
          final stringValues = decoded.values.whereType<String>();
          if (stringValues.isNotEmpty) {
            return stringValues.first;
          }
        }
      }
      return defaultMessage;
    } catch (e) {
      return defaultMessage;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final requestHeaders = {
        ..._defaultHeaders,
        ...headers,
        if (useAuth) ..._authHeaders,
      };

      // Build URI with query parameters only if they exist
      final uri = queryParameters.isNotEmpty
          ? Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters)
          : Uri.parse('$baseUrl$path');

      final response = await http.get(uri, headers: requestHeaders);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorMessage = _extractErrorMessage(
          response.body,
          'Request failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Request Failed');
        }
        return {
          'error': 'Failed GET: $path',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          'Network error. Please check your connection.',
          title: 'Connection Error',
        );
      }
      return {'error': 'Network error: $e', 'path': path};
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required dynamic body,
    Map<String, String> headers = const {},
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          ..._defaultHeaders,
          ...headers,
          if (useAuth) ..._authHeaders,
        },
        body: json.encode(body),
      );

      final responseBody = Map<String, dynamic>.from(
        json.decode(response.body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return responseBody;
      } else if (response.statusCode == 400) {
        // Check if 400 response contains error message
        final errorMessage = _extractErrorMessage(
          response.body,
          'Request failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Request Failed');
        }
        return responseBody;
      } else {
        final errorMessage = _extractErrorMessage(
          response.body,
          'Request failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Request Failed');
        }
        return {
          'error': 'Failed POST: $path',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          'Network error. Please check your connection.',
          title: 'Connection Error',
        );
      }
      return {'error': 'Network error: $e', 'path': path};
    }
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> data, {
    Map<String, String> headers = const {},
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          ..._defaultHeaders,
          ...headers,
          if (useAuth) ..._authHeaders,
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorMessage = _extractErrorMessage(
          response.body,
          'Update failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Update Failed');
        }
        return {
          'error': 'Failed PUT: $path',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          'Network error. Please check your connection.',
          title: 'Connection Error',
        );
      }
      return {'error': 'Network error: $e', 'path': path};
    }
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> data, {
    Map<String, String> headers = const {},
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          ..._defaultHeaders,
          ...headers,
          if (useAuth) ..._authHeaders,
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorMessage = _extractErrorMessage(
          response.body,
          'Update failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Update Failed');
        }
        return {
          'error': 'Failed PATCH: $path',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          'Network error. Please check your connection.',
          title: 'Connection Error',
        );
      }
      return {'error': 'Network error: $e', 'path': path};
    }
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String> headers = const {},
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: {..._defaultHeaders, ...headers, if (useAuth) ..._authHeaders},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return response.body.isEmpty
            ? {'success': true}
            : json.decode(response.body);
      } else {
        final errorMessage = _extractErrorMessage(
          response.body,
          'Delete failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Delete Failed');
        }
        return {
          'error': 'Failed DELETE: $path',
          'statusCode': response.statusCode,
          'message': response.body,
        };
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          'Network error. Please check your connection.',
          title: 'Connection Error',
        );
      }
      return {'error': 'Network error: $e', 'path': path};
    }
  }

  Future<Uint8List?> getBodyBytes(
    String path, {
    required dynamic body,
    Map<String, String> headers = const {},
    bool useAuth = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        body: body is String ? body : json.encode(body),
        headers: {...headers, if (useAuth) ..._authHeaders},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> getBytes(
    String path, {
    Map<String, String> headers = const {},
    bool useAuth = false,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: {...headers, if (useAuth) ..._authHeaders},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Multipart form-data POST for file uploads
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    List<File>? files,
    String fileFieldName = 'files[]',

    /// Files that each need their own field name (`ad_1`, `ad_2`) instead of
    /// sharing one repeated key like `files[]`.
    Map<String, File>? namedFiles,
    bool useAuth = true,
    bool showErrorAlert = true,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

      // Add headers
      request.headers['Accept'] = 'application/json';
      if (useAuth && _authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      // Add form fields (values must be strings for multipart)
      fields.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      if (files != null && files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();

          var filename = basename(file.path);
          if (!filename.contains('.')) {
            if (bytes.length >= 4) {
              if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
                filename = '$filename.jpg';
              } else if (bytes[0] == 0x89 && bytes[1] == 0x50) {
                filename = '$filename.png';
              } else if (bytes[0] == 0x52 && bytes[1] == 0x49) {
                filename = '$filename.webp';
              } else if (bytes[0] == 0x47 && bytes[1] == 0x49) {
                filename = '$filename.gif';
              } else if (bytes.length >= 8 &&
                  bytes[4] == 0x66 &&
                  bytes[5] == 0x74) {
                filename = '$filename.mp4';
              } else {
                filename = '$filename.jpg';
              }
            } else {
              filename = '$filename.jpg';
            }
          }

          final multipartFile = http.MultipartFile.fromBytes(
            fileFieldName,
            bytes,
            filename: filename,
          );
          request.files.add(multipartFile);
        }
      }

      // Files that need their own field name (ad_1, ad_2) rather than being
      // repeated under one key. Same extension-sniffing as above, since the
      // gallery can hand back paths with no suffix.
      if (namedFiles != null) {
        for (final entry in namedFiles.entries) {
          final bytes = await entry.value.readAsBytes();
          var filename = basename(entry.value.path);
          if (!filename.contains(".")) {
            final isMp4 =
                bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74;
            filename = isMp4 ? "$filename.mp4" : "$filename.jpg";
          }
          request.files.add(
            http.MultipartFile.fromBytes(entry.key, bytes, filename: filename),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception(
            'Upload timed out. Please try with smaller files or a better connection.',
          );
        },
      );
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.trimLeft().startsWith('<')) {
        final msg = response.statusCode == 413
            ? 'File too large. Please reduce file size.'
            : 'Server error (${response.statusCode}). Please try again.';
        if (showErrorAlert) {
          _showErrorAlert(msg, title: 'Upload Failed');
        }
        return {'error': msg, 'statusCode': response.statusCode};
      }

      Map<String, dynamic> responseBody;
      try {
        responseBody = Map<String, dynamic>.from(json.decode(response.body));
      } catch (_) {
        final msg = 'Unexpected server response (${response.statusCode})';
        if (showErrorAlert) {
          _showErrorAlert(msg, title: 'Upload Failed');
        }
        return {'error': msg, 'statusCode': response.statusCode};
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return responseBody;
      } else {
        final errorMessage = _extractErrorMessage(
          response.body,
          'Upload failed',
        );
        if (showErrorAlert) {
          _showErrorAlert(errorMessage, title: 'Upload Failed');
        }
        // Only supply an `error` when the body didn't carry one. Assigning
        // unconditionally destroyed the server's own explanation — a 500 comes
        // back as {message: "Something went wrong", error: "SQLSTATE[...]"},
        // and overwriting `error` with "Failed: 500" threw away the only line
        // that said what actually broke. Callers detect failure by the key's
        // presence, which still holds.
        responseBody['statusCode'] = response.statusCode;
        responseBody.putIfAbsent(
          'error',
          () => 'Failed: ${response.statusCode}',
        );
        return responseBody;
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          e.toString().contains('timed out')
              ? 'Upload timed out. Please try with a better connection.'
              : 'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
          title: 'Upload Error',
        );
      }
      return {'error': 'Upload error: $e', 'path': path};
    }
  }
}
