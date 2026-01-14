import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your machine's IP address
  static const String baseUrl = "http://192.168.1.47:4000"; 
  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'jwt_token', value: data['token']);
      await _storage.write(key: 'user_role', value: data['role']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String role) async {
    // Backend requires 'walletAddress' but in this flow backend manages it. 
    // We send a placeholder or let backend generate it. 
    // Looking at backend code: it requires walletAddress in body.
    // For now, we will generate a random one or send a placeholder.
    // Ideally backend should generate it if not provided.
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email, 
        'password': password, 
        'role': role,
        'walletAddress': '0x0000000000000000000000000000000000000000' // Placeholder
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
  }

  Future<Map<String, dynamic>> createProduct(String location) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/product'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'location': location}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to mint product');
    }
  }

  Future<Map<String, dynamic>> addRetailerHop(String productId, String location) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/product/$productId/retailer-hop'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'location': location}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to add hop');
    }
  }

  Future<Map<String, dynamic>> getProduct(String productId) async {
    final response = await http.get(Uri.parse('$baseUrl/product/$productId'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch product');
    }
  }
}
