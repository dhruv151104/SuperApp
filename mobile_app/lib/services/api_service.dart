import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your machine's IP address
  static const String baseUrl = "http://192.168.1.35:4000"; 
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
      if(data['companyName'] != null) await _storage.write(key: 'company_name', value: data['companyName']);
      if(data['registeredLocation'] != null) await _storage.write(key: 'registered_location', value: data['registeredLocation']);
      if(data['contactPerson'] != null) await _storage.write(key: 'contact_person', value: data['contactPerson']);
      if(data['contactPhone'] != null) await _storage.write(key: 'contact_phone', value: data['contactPhone']);
      if(data['walletAddress'] != null) await _storage.write(key: 'wallet_address', value: data['walletAddress']);
      if(data['licenseId'] != null) await _storage.write(key: 'license_id', value: data['licenseId']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> register(
      String email, 
      String password, 
      String role,
      String companyName,
      String? registeredLocation, // Optional
      String licenseId,
      String businessType,
      String contactPerson,
      String contactPhone
  ) async {
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email, 
        'password': password, 
        'role': role,
        'walletAddress': '0x0000000000000000000000000000000000000000', // Placeholder
        'companyName': companyName,
        'registeredLocation': registeredLocation,
        'licenseId': licenseId,
        'businessType': businessType,
        'contactPerson': contactPerson,
        'contactPhone': contactPhone
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
    await _storage.deleteAll(); // Clear all
  }

  Future<Map<String, dynamic>> createProduct(String location, String productName, {List<String>? flags, String? imagePath}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/product');
    
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      // Content-Type is auto-set to multipart/form-data
    });

    request.fields['location'] = location;
    request.fields['productName'] = productName;
    // For arrays in multipart, often easier to JSON encode or separate fields. 
    // Backend logic: `if (typeof clientFlags === 'string') JSON.parse...`
    // Or node multer handles array if same key used multiple times? 
    // Let's use JSON string for simplicity as my backend handles parsing for retailer. 
    // Wait, createProduct backend: `req.body` with multer populates fields. 
    // Safest is to just send simple fields or check backend.
    // I'll stick to a simple strategy: duplicate keys for array OR json string.
    // Let's do JSON string for flags if backend supports or just simple if empty.
    // Actually backend `createProduct` expects `req.body.flags`.
    // Let's send it as individual fields if possible or JSON.
    // I will modify backend to parse JSON string if needed, but for now let's try sending as multiple fields?
    // No, standard is `flags[]` or just `flags`. 
    // I will try just sending it, if it fails I'll fix backend.
    if (flags != null) {
       for(var f in flags) {
         request.fields['flags'] = f; // This overwrites? Yes in plain Map.
         // Http MultiPartRequest fields is Map<String, String>. It CANNOT hold array.
         // So I MUST send as one JSON string or modify backend to read duplicates?
         // Dart http doesn't support duplicates in `fields` map easily?
         // Actually `http.MultipartRequest` has `fields` which is `Map<String, String>`.
         // So I MUST use JSON string (serialized).
       }
       // BETTER: Send as JSON string
       request.fields['flags'] = jsonEncode(flags); 
    }
    
    if (imagePath != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to mint product');
    }
  }

  Future<Map<String, dynamic>> addRetailerHop(String productId, String location, {List<String>? flags, String? imagePath}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/product/$productId/retailer-hop');
    
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    request.fields['location'] = location;
    if (flags != null) {
       request.fields['flags'] = jsonEncode(flags);
    }
    
    if (imagePath != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

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

  Future<Map<String, String?>> getUserProfile() async {
    return {
      'companyName': await _storage.read(key: 'company_name'),
      'registeredLocation': await _storage.read(key: 'registered_location'),
      'role': await _storage.read(key: 'user_role'),
      'contactPerson': await _storage.read(key: 'contact_person'),
      'contactPhone': await _storage.read(key: 'contact_phone'),
      'walletAddress': await _storage.read(key: 'wallet_address'),
      'licenseId': await _storage.read(key: 'license_id'),
    };
  }

  Future<List<dynamic>> getUserHistory() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/user/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to fetch user history');
    }
  }

  Future<Map<String, dynamic>> getAnalyticsDashboard() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch analytics');
    }
  }

  Future<Map<String, dynamic>> analyzeImage(String imagePath, {String? productId}) async {
    final uri = Uri.parse('$baseUrl/analyze');
    var request = http.MultipartRequest('POST', uri);
    
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    if (productId != null) {
      request.fields['productId'] = productId;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
       return jsonDecode(response.body);
    } else {
       throw Exception("Analysis failed");
    }
  }

  Future<List<dynamic>> getAnalyticsPartners() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/partners'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to fetch partners');
    }
  }
}
