import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class HostsView extends StatefulWidget {
  final ApiService apiService;

  const HostsView({super.key, required this.apiService});

  @override
  State<HostsView> createState() => _HostsViewState();
}

class _HostsViewState extends State<HostsView> {
  List<RemoteHost> _hosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    setState(() => _isLoading = true);
    final list = await widget.apiService.getHosts();
    if (mounted) {
      setState(() {
        _hosts = list;
        _isLoading = false;
      });
    }
  }

  void _showAddHostDialog() {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '22');
    final userCtrl = TextEditingController(text: 'root');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('纳管新 Linux 主机 (SSH)', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: '节点别名 (如: 生产K8s-Node01)', labelStyle: TextStyle(color: Colors.grey)),
            ),
            TextField(
              controller: ipCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: '主机 IP 或域名', labelStyle: TextStyle(color: Colors.grey)),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'SSH 用户', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: portCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'SSH 端口', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              if (ipCtrl.text.trim().isEmpty) return;
              final p = int.tryParse(portCtrl.text) ?? 22;
              final host = RemoteHost(
                id: 'host_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim().isEmpty ? ipCtrl.text.trim() : nameCtrl.text.trim(),
                host: ipCtrl.text.trim(),
                port: p,
                user: userCtrl.text.trim(),
                status: 'online',
                lastPing: '刚刚',
              );
              await widget.apiService.addHost(host);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                _loadHosts();
              }
            },
            child: const Text('添加', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('纳管 Linux 节点资产', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _showAddHostDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加主机', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _hosts.length,
              itemBuilder: (ctx, idx) {
                final h = _hosts[idx];
                final isLocal = h.id == 'local';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181B22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262B36)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isLocal ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isLocal ? Icons.computer : Icons.dns,
                          color: isLocal ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  h.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('已就绪', style: TextStyle(color: Color(0xFF10B981), fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SSH 连接: ${h.user}@${h.host}:${h.port}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
