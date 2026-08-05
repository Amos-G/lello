import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';

const backendUrl = 'https://partysync.amosgranata.it';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class Api {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const requestTimeout = Duration(seconds: 15);
  String? token;

  Uri _uri(String path) => Uri.parse('$backendUrl$path');
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final uri = _uri(path);
    late http.Response response;
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        response =
            await http.get(uri, headers: _headers).timeout(requestTimeout);
      case 'POST':
        response = await http
            .post(uri, headers: _headers, body: encoded)
            .timeout(requestTimeout);
      case 'PATCH':
        response = await http
            .patch(uri, headers: _headers, body: encoded)
            .timeout(requestTimeout);
      case 'DELETE':
        response = await http
            .delete(uri, headers: _headers, body: encoded)
            .timeout(requestTimeout);
      default:
        throw StateError('Metodo sconosciuto');
    }
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        data = null;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (data is Map ? data['error'] : null) ??
            'Errore HTTP ${response.statusCode}',
        response.statusCode,
      );
    }
    if (response.body.isNotEmpty && data == null) {
      throw ApiException('Risposta non valida dal server', response.statusCode);
    }
    return data;
  }

  Future<bool> restoreSession() async {
    token = await storage.read(key: 'jwt');
    if (token == null) return false;
    try {
      await me();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/auth/login', {
          'username': username,
          'password': password,
        }),
      );

  Future<void> acceptToken(String value) async {
    token = value;
    await storage.write(key: 'jwt', value: value);
  }

  Future<void> verify2fa(String ticket, String code) async {
    final data = await _request('POST', '/api/auth/verify-2fa', {
      'login_ticket': ticket,
      'code': code,
    });
    await acceptToken(data['token']);
  }

  Future<void> logout() async {
    token = null;
    await storage.delete(key: 'jwt');
  }

  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/auth/me'));
  Future<Map<String, dynamic>> setup2fa() async => Map<String, dynamic>.from(
        await _request('POST', '/api/auth/2fa/setup', {}),
      );
  Future<void> enable2fa(String code) =>
      _request('POST', '/api/auth/2fa/enable', {'code': code});
  Future<void> disable2fa(String password) =>
      _request('POST', '/api/auth/2fa/disable', {'password': password});

  Future<List<Elemento>> elementi() async =>
      (await _request('GET', '/api/elementi') as List)
          .map((e) => Elemento.fromJson(e))
          .toList();
  Future<Elemento> createElemento(String nome, String chiPorta) async =>
      Elemento.fromJson(
        Map<String, dynamic>.from(
          await _request('POST', '/api/elementi', {
            'nome': nome,
            'chi_porta': chiPorta,
          }),
        ),
      );
  Future<void> addElemento(String nome, String chiPorta) async {
    await createElemento(nome, chiPorta);
  }

  Future<void> patchElemento(int id, Map<String, dynamic> patch) =>
      _request('PATCH', '/api/elementi/$id', patch);
  Future<void> deleteElemento(int id) =>
      _request('DELETE', '/api/elementi/$id');

  Future<List<Scenario>> scenari() async =>
      (await _request('GET', '/api/scenari') as List)
          .map((e) => Scenario.fromJson(e))
          .toList();
  Future<void> addScenario(String titolo) =>
      _request('POST', '/api/scenari', {'titolo': titolo});
  Future<void> deleteScenario(int id) => _request('DELETE', '/api/scenari/$id');
  Future<void> attach(int scenarioId, int elementId) =>
      _request('POST', '/api/scenari/$scenarioId/elementi/$elementId', {});
  Future<void> createAndAttach(
    int scenarioId,
    String nome,
    String chiPorta,
  ) async {
    final item = await createElemento(nome, chiPorta);
    try {
      await attach(scenarioId, item.id);
    } catch (_) {
      try {
        await deleteElemento(item.id);
      } catch (_) {
        // Il rollback best-effort non deve nascondere l'errore di associazione.
      }
      rethrow;
    }
  }

  Future<void> detach(int scenarioId, int elementId) =>
      _request('DELETE', '/api/scenari/$scenarioId/elementi/$elementId');

  Future<WebSocketChannel> socket() async {
    final wsBase = backendUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws'));
    await channel.ready.timeout(requestTimeout);
    channel.sink.add(jsonEncode({'type': 'auth', 'token': token!}));
    return channel;
  }
}
