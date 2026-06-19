import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String birthdate,
    required String gender,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
        'birthdate': birthdate,
        'gender': gender,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Registration failed');
    }
    await _saveToken(jsonDecode(res.body)['token']);
  }

  Future<void> login({required String email, required String password}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Login failed');
    }
    await _saveToken(jsonDecode(res.body)['token']);
  }

  Future<int> getTickets() async {
    final res = await http.get(Uri.parse('$baseUrl/jackpot/tickets'), headers: await _authHeaders());
    return jsonDecode(res.body)['tickets'];
  }

  Future<Map<String, dynamic>> spinJackpot() async {
    final res = await http.post(Uri.parse('$baseUrl/jackpot/spin'), headers: await _authHeaders());
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Spin failed');
    }
    return body['result'];
  }

  Future<bool> likeSpinResult(int matchedUserId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/jackpot/spin/$matchedUserId/like'),
      headers: await _authHeaders(),
    );
    return jsonDecode(res.body)['mutualMatch'] == true;
  }
}
