import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  String baseUrl = 'http://127.0.0.1:8080';

  Future<SystemMetrics?> getMetrics() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/metrics')).timeout(
            const Duration(seconds: 4),
          );
      if (res.statusCode == 200) {
        return SystemMetrics.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }

  Future<List<RemoteHost>> getHosts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/hosts'));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((h) => RemoteHost.fromJson(h)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addHost(RemoteHost host) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/hosts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': host.id,
          'name': host.name,
          'host': host.host,
          'port': host.port,
          'user': host.user,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<SOPPlaybook>> getRunbooks() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/runbooks'));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((p) => SOPPlaybook.fromJson(p)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ChatMessage?> sendChat(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );
      if (res.statusCode == 200) {
        return ChatMessage.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }

  Future<ExecutionResult?> executeCommand(String hostId, String command) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'host_id': hostId, 'command': command}),
      );
      if (res.statusCode == 200) {
        return ExecutionResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }

  Future<BlastRadius?> checkGuardrail(String command) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/guardrail/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      );
      if (res.statusCode == 200) {
        return BlastRadius.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    return null;
  }
}
