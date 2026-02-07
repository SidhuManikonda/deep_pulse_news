import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import '../constants/app_constants.dart';
import '../../shared/widgets/alert_popup.dart';

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
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

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
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final requestHeaders = {...headers, if (useAuth) ..._authHeaders};

      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: requestHeaders,
      );
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

  Future<dynamic> delete(
    String path, {
    Map<String, String> headers = const {},
    bool useAuth = false,
    bool showErrorAlert = true,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: {...headers, if (useAuth) ..._authHeaders},
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
    required Map<String, String> fields,
    List<File>? files,
    String fileFieldName = 'files[]',
    bool useAuth = true,
    bool showErrorAlert = true,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

      // Add headers
      if (useAuth && _authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      // Add form fields
      request.fields.addAll(fields);

      // Add files
      if (files != null && files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final multipartFile = http.MultipartFile.fromBytes(
            fileFieldName,
            bytes,
            filename: basename(file.path),
          );
          request.files.add(multipartFile);
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseBody = Map<String, dynamic>.from(
        json.decode(response.body),
      );

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
        return responseBody;
      }
    } catch (e) {
      if (showErrorAlert) {
        _showErrorAlert(
          'Network error during upload. Please check your connection.',
          title: 'Upload Error',
        );
      }
      return {'error': 'Network error: $e', 'path': path};
    }
  }
}
