import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/lyrics.dart';
import '../models/user.dart';
import '../models/playlist.dart';

class ApiService extends ChangeNotifier {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = '';
  String? _token;
  UserProfile? _currentUser;
  String? lastError;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');

    // Production Render backend as default
    const String defaultUrl = 'https://yuno-backend-je37.onrender.com';
    _baseUrl = prefs.getString('backend_url') ?? defaultUrl;

    if (_token != null) {
      await fetchMe();
    }
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', _baseUrl);
    notifyListeners();
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  String getStreamUrl(String trackId) {
    return '$_baseUrl/api/v1/stream/$trackId';
  }

  // --- AUTH ---

  Future<bool> register(String email, String username, String password) async {
    lastError = null;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 12));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['access_token'];
        _currentUser = UserProfile.fromJson(data['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        notifyListeners();
        return true;
      } else {
        try {
          final errData = jsonDecode(res.body);
          lastError = errData['detail'] ?? 'Ошибка сервера (${res.statusCode})';
        } catch (_) {
          lastError = 'Ошибка сервера (${res.statusCode})';
        }
      }
    } catch (e) {
      lastError = 'Таймаут или ошибка сети: $e';
      debugPrint('Register error: $e');
    }
    return false;
  }

  Future<bool> login(String email, String password) async {
    lastError = null;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 12));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['access_token'];
        _currentUser = UserProfile.fromJson(data['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        notifyListeners();
        return true;
      } else {
        try {
          final errData = jsonDecode(res.body);
          lastError = errData['detail'] ?? 'Ошибка входа (${res.statusCode})';
        } catch (_) {
          lastError = 'Ошибка входа (${res.statusCode})';
        }
      }
    } catch (e) {
      lastError = 'Таймаут или ошибка сети: $e';
      debugPrint('Login error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> fetchMe() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/auth/me'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        _currentUser = UserProfile.fromJson(jsonDecode(res.body));
        notifyListeners();
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('Fetch me error: $e');
    }
  }

  // --- FEED & SEARCH ---

  Future<Map<String, dynamic>> getFeed() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/feed'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        var trendingList = (data['trending'] as List? ?? [])
            .map((t) => Track.fromJson(t))
            .toList();

        List<Map<String, dynamic>> shelves = [];
        for (var s in (data['shelves'] as List? ?? [])) {
          shelves.add({
            'title': s['title'],
            'items': (s['items'] as List? ?? []).map((t) => Track.fromJson(t)).toList(),
          });
        }
        return {'trending': trendingList, 'shelves': shelves};
      }
    } catch (e) {
      debugPrint('Feed error: $e');
    }
    return {'trending': <Track>[], 'shelves': <Map<String, dynamic>>[]};
  }

  Future<List<Track>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/search').replace(queryParameters: {'q': query});
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((t) => Track.fromJson(t)).toList();
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    return [];
  }

  // --- LYRICS ---

  Future<LyricsData?> getLyrics(String title, String artist, {String? album, int? durationS}) async {
    try {
      final params = {'title': title, 'artist': artist};
      if (album != null) params['album'] = album;
      if (durationS != null) params['duration_s'] = durationS.toString();

      final uri = Uri.parse('$_baseUrl/api/v1/lyrics').replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return LyricsData.fromJson(data);
      }
    } catch (e) {
      debugPrint('Lyrics error: $e');
    }
    return null;
  }

  // --- PLAYLISTS & FAVORITES ---

  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/v1/playlists'), headers: _headers());
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((p) => PlaylistModel.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('Playlists error: $e');
    }
    return [];
  }

  Future<PlaylistModel?> createPlaylist(String title, {String? description}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/playlists'),
        headers: _headers(),
        body: jsonEncode({'title': title, 'description': description}),
      );
      if (res.statusCode == 200) {
        return PlaylistModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Create playlist error: $e');
    }
    return null;
  }

  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/playlists/$playlistId/tracks'),
        headers: _headers(),
        body: jsonEncode(track.toJson()),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Add track error: $e');
    }
    return false;
  }

  Future<List<Track>> getFavorites() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/v1/favorites'), headers: _headers());
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((t) => Track.fromJson(t)).toList();
      }
    } catch (e) {
      debugPrint('Favorites error: $e');
    }
    return [];
  }

  Future<bool> toggleFavorite(Track track) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/favorites'),
        headers: _headers(),
        body: jsonEncode(track.toJson()),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['is_favorite'] == true;
      }
    } catch (e) {
      debugPrint('Toggle favorite error: $e');
    }
    return false;
  }

  Future<void> recordHistory(Track track) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/history'),
        headers: _headers(),
        body: jsonEncode(track.toJson()),
      );
    } catch (_) {}
  }
}
