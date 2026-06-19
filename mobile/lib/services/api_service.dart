import 'dart:convert';
import 'dart:io';
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

  Future<int?> currentUserId() async {
    final token = await _token();
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload)['userId'] as int?;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeOrThrow(http.Response res, int expectedStatus) {
    final body = jsonDecode(res.body);
    if (res.statusCode != expectedStatus) {
      throw Exception(body['error'] ?? 'Request failed');
    }
    return body;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String birthdate,
    required String gender,
    String? pronouns,
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
        'pronouns': pronouns,
      }),
    );
    final body = _decodeOrThrow(res, 201);
    await _saveToken(body['token']);
    return body['emailVerified'] == true;
  }

  Future<void> login({required String email, required String password}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decodeOrThrow(res, 200);
    await _saveToken(body['token']);
  }

  Future<void> verifyEmail({required String email, required String code}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    _decodeOrThrow(res, 200);
  }

  Future<void> resendVerification({required String email}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/resend-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    _decodeOrThrow(res, 200);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await http.get(Uri.parse('$baseUrl/categories'), headers: await _authHeaders());
    final body = _decodeOrThrow(res, 200) as List;
    return body.cast<Map<String, dynamic>>();
  }

  Future<void> proposeCategory(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode != 201 && res.statusCode != 409) {
      _decodeOrThrow(res, 201);
    }
  }

  Future<void> setCategories(List<int> categoryIds) async {
    final res = await http.put(
      Uri.parse('$baseUrl/profile/categories'),
      headers: await _authHeaders(),
      body: jsonEncode({'categoryIds': categoryIds}),
    );
    _decodeOrThrow(res, 200);
  }

  Future<void> updateProfile({String? bio, String? pronouns}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/profile'),
      headers: await _authHeaders(),
      body: jsonEncode({'bio': bio, 'pronouns': pronouns}),
    );
    _decodeOrThrow(res, 200);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(Uri.parse('$baseUrl/profile'), headers: await _authHeaders());
    return _decodeOrThrow(res, 200);
  }

  Future<void> deletePhoto(int photoId) async {
    final res = await http.delete(Uri.parse('$baseUrl/profile/photos/$photoId'), headers: await _authHeaders());
    if (res.statusCode != 204) {
      throw Exception('Failed to delete photo');
    }
  }

  Future<Map<String, dynamic>?> getPreferences() async {
    final res = await http.get(Uri.parse('$baseUrl/preferences'), headers: await _authHeaders());
    final body = _decodeOrThrow(res, 200);
    return body as Map<String, dynamic>?;
  }

  Future<void> updatePreferences({
    required String interestedIn,
    required int minAge,
    required int maxAge,
    required int maxDistanceKm,
    required String lookingFor,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/preferences'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'interestedIn': interestedIn,
        'minAge': minAge,
        'maxAge': maxAge,
        'maxDistanceKm': maxDistanceKm,
        'lookingFor': lookingFor,
      }),
    );
    _decodeOrThrow(res, 200);
  }

  Future<void> uploadPhoto(File file) async {
    final headers = await _authHeaders();
    headers.remove('Content-Type');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/profile/photos'))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('photo', file.path));
    final streamed = await request.send();
    if (streamed.statusCode != 201) {
      final body = await streamed.stream.bytesToString();
      throw Exception(jsonDecode(body)['error'] ?? 'Photo upload failed');
    }
  }

  Future<Map<String, dynamic>> getCompletion() async {
    final res = await http.get(Uri.parse('$baseUrl/profile/completion'), headers: await _authHeaders());
    return _decodeOrThrow(res, 200);
  }

  Future<int> getTickets() async {
    final res = await http.get(Uri.parse('$baseUrl/jackpot/tickets'), headers: await _authHeaders());
    return jsonDecode(res.body)['tickets'];
  }

  String? photoUrl(String? path) => path == null ? null : '$baseUrl$path';

  Future<Map<String, dynamic>> spinJackpot() async {
    final res = await http.post(Uri.parse('$baseUrl/jackpot/spin'), headers: await _authHeaders());
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Spin failed');
    }
    return {
      'result': body['result'],
      'decoys': (body['decoys'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    };
  }

  Future<bool> likeSpinResult(int matchedUserId, {bool mega = false}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/jackpot/spin/$matchedUserId/like'),
      headers: await _authHeaders(),
      body: jsonEncode({'mega': mega}),
    );
    return jsonDecode(res.body)['mutualMatch'] == true;
  }

  Future<Map<String, dynamic>> spinBoost() async {
    final res = await http.post(Uri.parse('$baseUrl/jackpot/spin/boost'), headers: await _authHeaders());
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Boost spin failed');
    }
    return {
      'result': body['result'],
      'decoys': (body['decoys'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    };
  }

  Future<Map<String, dynamic>> claimDailyTickets() async {
    final res = await http.post(Uri.parse('$baseUrl/jackpot/tickets/claim-daily'), headers: await _authHeaders());
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Claim failed');
    }
    return body;
  }

  Future<Map<String, dynamic>> watchAdForTicket() async {
    final res = await http.post(Uri.parse('$baseUrl/jackpot/tickets/watch-ad'), headers: await _authHeaders());
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Ad reward failed');
    }
    return body;
  }

  Future<void> blockUser(int userId) async {
    final res = await http.post(Uri.parse('$baseUrl/users/$userId/block'), headers: await _authHeaders());
    _decodeOrThrow(res, 201);
  }

  Future<void> reportUser(int userId, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/report'),
      headers: await _authHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    _decodeOrThrow(res, 201);
  }

  Future<void> markRead(int matchId) async {
    final res = await http.post(Uri.parse('$baseUrl/matches/$matchId/read'), headers: await _authHeaders());
    _decodeOrThrow(res, 200);
  }

  Future<void> uploadVerificationPhoto(File file) async {
    final headers = await _authHeaders();
    headers.remove('Content-Type');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/profile/verification'))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('photo', file.path));
    final streamed = await request.send();
    if (streamed.statusCode != 201) {
      final body = await streamed.stream.bytesToString();
      throw Exception(jsonDecode(body)['error'] ?? 'Verification upload failed');
    }
  }

  Future<List<Map<String, dynamic>>> getUserPhotos(int userId) async {
    final res = await http.get(Uri.parse('$baseUrl/users/$userId/photos'), headers: await _authHeaders());
    final body = _decodeOrThrow(res, 200) as List;
    return body.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMatches() async {
    final res = await http.get(Uri.parse('$baseUrl/matches'), headers: await _authHeaders());
    final body = _decodeOrThrow(res, 200) as List;
    return body.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMessages(int matchId) async {
    final res = await http.get(Uri.parse('$baseUrl/matches/$matchId/messages'), headers: await _authHeaders());
    final body = _decodeOrThrow(res, 200) as List;
    return body.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendMessage(int matchId, String body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/matches/$matchId/messages'),
      headers: await _authHeaders(),
      body: jsonEncode({'body': body}),
    );
    return _decodeOrThrow(res, 201);
  }
}
