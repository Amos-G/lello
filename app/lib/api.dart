import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

const backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://partysync.amosgranata.it',
);

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

  final http.Client client;
  final void Function()? onUnauthorized;
  String? token;

  Api({http.Client? client, this.onUnauthorized})
      : client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$backendUrl$path');
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final uri = _uri(path);
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response response;
    switch (method) {
      case 'GET':
        response =
            await client.get(uri, headers: _headers).timeout(requestTimeout);
      case 'POST':
        response = await client
            .post(uri, headers: _headers, body: encoded)
            .timeout(requestTimeout);
      case 'PATCH':
        response = await client
            .patch(uri, headers: _headers, body: encoded)
            .timeout(requestTimeout);
      case 'DELETE':
        response = await client
            .delete(uri, headers: _headers, body: encoded)
            .timeout(requestTimeout);
      default:
        throw StateError('Metodo HTTP sconosciuto');
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
      if (response.statusCode == 401 && token != null) {
        await logout();
        onUnauthorized?.call();
      }
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

  Future<bool> restoreToken() async {
    token = await storage.read(key: 'jwt');
    return token != null;
  }

  Future<Map<String, dynamic>> login(String username, String password) async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/auth/login', {
          'username': username,
          'password': password,
        }),
      );

  Future<Map<String, dynamic>> register({
    required String inviteCode,
    required String username,
    required String password,
  }) async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/auth/register', {
          'invite_code': inviteCode.trim(),
          'username': username.trim(),
          'password': password,
        }),
      );

  Future<Map<String, dynamic>> createRegistrationInvite() async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/inviti-registrazione', {}),
      );

  Future<void> acceptToken(String value) async {
    token = value;
    await storage.write(key: 'jwt', value: value);
  }

  Future<void> verify2fa(String ticket, String code) async {
    final data = Map<String, dynamic>.from(
      await _request('POST', '/api/auth/verify-2fa', {
        'login_ticket': ticket,
        'code': code,
      }),
    );
    await acceptToken(data['token'] as String);
  }

  Future<void> logout() async {
    token = null;
    await storage.delete(key: 'jwt');
  }

  Future<AppUser> me() async => AppUser.fromJson(
        Map<String, dynamic>.from(await _request('GET', '/api/auth/me')),
      );

  Future<Map<String, dynamic>> setup2fa() async => Map<String, dynamic>.from(
        await _request('POST', '/api/auth/2fa/setup', {}),
      );
  Future<void> enable2fa(String code) =>
      _request('POST', '/api/auth/2fa/enable', {'code': code});
  Future<void> disable2fa(String password) =>
      _request('POST', '/api/auth/2fa/disable', {'password': password});

  Future<List<PartyList>> lists() async =>
      (await _request('GET', '/api/liste') as List)
          .map((e) => PartyList.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<void> createList(String nome) =>
      _request('POST', '/api/liste', {'nome': nome});
  Future<void> deleteList(String listId) =>
      _request('DELETE', '/api/liste/$listId');

  Future<List<Participant>> participants(String listId) async =>
      (await _request('GET', '/api/liste/$listId/partecipanti') as List)
          .map((e) => Participant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<List<Participant>> invitables(String listId) async =>
      (await _request('GET', '/api/liste/$listId/invitabili') as List)
          .map((e) => Participant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<void> invite(String listId, String userId) =>
      _request('POST', '/api/liste/$listId/inviti', {'utente_id': userId});

  Future<List<Elemento>> elementi(String listId) async =>
      (await _request('GET', '/api/liste/$listId/elementi') as List)
          .map((e) => Elemento.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<Elemento> createElemento(
    String listId,
    String nome,
    String? assigneeUserId,
  ) async =>
      Elemento.fromJson(
        Map<String, dynamic>.from(
          await _request('POST', '/api/liste/$listId/elementi', {
            'nome': nome,
            'chi_porta_utente_id': assigneeUserId,
          }),
        ),
      );
  Future<void> patchElemento(
    String listId,
    String id,
    Map<String, dynamic> patch,
  ) =>
      _request('PATCH', '/api/liste/$listId/elementi/$id', patch);
  Future<void> deleteElemento(String listId, String id) =>
      _request('DELETE', '/api/liste/$listId/elementi/$id');
  Future<EtichetteReport> etichette(String listId) async =>
      EtichetteReport.fromJson(
        Map<String, dynamic>.from(
          await _request('GET', '/api/liste/$listId/etichette'),
        ),
      );

  Future<List<Scenario>> scenari(String listId) async =>
      (await _request('GET', '/api/liste/$listId/scenari') as List)
          .map((e) => Scenario.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<void> addScenario(String listId, String title) =>
      _request('POST', '/api/liste/$listId/scenari', {'titolo': title});
  Future<void> renameScenario(String listId, String id, String title) =>
      _request('PATCH', '/api/liste/$listId/scenari/$id', {'titolo': title});
  Future<void> deleteScenario(String listId, String id) =>
      _request('DELETE', '/api/liste/$listId/scenari/$id');
  Future<void> attach(String listId, String scenarioId, String elementId) =>
      _request(
        'POST',
        '/api/liste/$listId/scenari/$scenarioId/elementi/$elementId',
        {},
      );
  Future<void> detach(String listId, String scenarioId, String elementId) =>
      _request(
        'DELETE',
        '/api/liste/$listId/scenari/$scenarioId/elementi/$elementId',
      );
  Future<void> createAndAttach(
    String listId,
    String scenarioId,
    String name,
    String? assigneeUserId,
  ) async {
    final item = await createElemento(listId, name, assigneeUserId);
    try {
      await attach(listId, scenarioId, item.id);
    } catch (_) {
      try {
        await deleteElemento(listId, item.id);
      } catch (_) {}
      rethrow;
    }
  }

  Future<SpeseReport> spese(String listId) async => SpeseReport.fromJson(
        Map<String, dynamic>.from(
          await _request('GET', '/api/liste/$listId/spese'),
        ),
      );
  Future<void> addSpesa(
    String listId,
    String description,
    int amountCents,
    List<String> participantIds,
  ) =>
      _request('POST', '/api/liste/$listId/spese', {
        'descrizione': description,
        'importo_cents': amountCents,
        'partecipante_ids': participantIds,
      });
  Future<void> deleteSpesa(String listId, String id) =>
      _request('DELETE', '/api/liste/$listId/spese/$id');
  Future<void> addPayment(
    String listId,
    String toUserId,
    int amountCents,
    String? note,
  ) =>
      _request('POST', '/api/liste/$listId/pagamenti', {
        'a_utente_id': toUserId,
        'importo_cents': amountCents,
        if (note != null && note.isNotEmpty) 'nota': note,
      });
  Future<void> deletePayment(String listId, String id) =>
      _request('DELETE', '/api/liste/$listId/pagamenti/$id');

  Future<List<AdminUser>> adminUsers() async =>
      (await _request('GET', '/api/admin/utenti') as List)
          .map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
  Future<void> createUser(
    String username,
    String password,
    String role, {
    bool canInviteUsers = false,
  }) =>
      _request('POST', '/api/admin/utenti', {
        'username': username,
        'password': password,
        'ruolo': role,
        'can_invite_users': canInviteUsers,
      });
  Future<void> updateUser(
    String id, {
    String? role,
    String? password,
    bool? canInviteUsers,
  }) =>
      _request('PATCH', '/api/admin/utenti/$id', {
        if (role != null) 'ruolo': role,
        if (password != null) 'password': password,
        if (canInviteUsers != null) 'can_invite_users': canInviteUsers,
      });
  Future<void> deleteUser(String id) =>
      _request('DELETE', '/api/admin/utenti/$id');

  Future<WebSocketChannel> socket() async {
    final base = Uri.parse(backendUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      queryParameters: {'token': token!},
    );
    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(requestTimeout);
    return channel;
  }
}
