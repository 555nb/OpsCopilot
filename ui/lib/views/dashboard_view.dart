import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class DashboardView extends StatefulWidget {
  final ApiService apiService;
  final Function(String) onTriggerDoctor;

  const DashboardView({
    super.key,
    required this.apiService,
    required this.onTriggerDoctor,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  SystemMetrics? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final m = await widget.apiService.getMetrics();
    if (mounted) {
      setState(() {
        _metrics = m;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_metrics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              '未能连接到 OpsCopilot 后端守护进程 (http://127.0.0.1:8080)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMetrics,
              icon: const Icon(Icons.refresh),
              label: const Text('重试连接'),
            ),
          ],
        ),
      );
    }

    final m = _metrics!;
    final isHighLoad = m.loadAvg.load1 > 4.0;
    final hasOOM = m.oomEvents.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderBanner(m),
          const SizedBox(height: 16),
          if (hasOOM) _buildOOMAlert(m.oomEvents),
          if (isHighLoad) _buildHighLoadAlert(m.loadAvg.load1),
          const SizedBox(height: 8),
          _buildMetricsGrid(m),
          const SizedBox(height: 16),
          _buildDisksCard(m.disks),
          const SizedBox(height: 16),
          _buildTopProcessesCard(m.topProcesses),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(SystemMetrics m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C3240)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.dns, color: Color(0xFF60A5FA), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.hostname,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '平台: ${m.os} | 僵尸进程: ${m.zombieProcesses} | 异常服务: ${m.failedServices.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => widget.onTriggerDoctor('请对当前系统运行状态进行全面健康诊断并指出潜在隐患'),
            icon: const Icon(Icons.health_and_safety, size: 16),
            label: const Text('一键智能体检'),
          ),
        ],
      ),
    );
  }

  Widget _buildOOMAlert(List<String> oomList) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDC2626)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '检测到系统存在内核 OOM-killer 强杀事件记录 (${oomList.length}次)，建议立即排查内存泄露！',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighLoadAlert(double load1) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF78350F).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD97706)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFFFBBF24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '当前1分钟负载达到 ${load1.toStringAsFixed(2)}，队列压力偏高，建议点击“一键智能体检”排查高消耗进程！',
              style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(SystemMetrics m) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final children = [
          _buildStatCard(
            title: '系统负载 (1m / 5m / 15m)',
            value: '${m.loadAvg.load1.toStringAsFixed(2)} / ${m.loadAvg.load5.toStringAsFixed(2)} / ${m.loadAvg.load15.toStringAsFixed(2)}',
            subtitle: 'CPU 使用率: ${m.cpuUsage.toStringAsFixed(1)}%',
            color: const Color(0xFF10B981),
            icon: Icons.speed,
          ),
          _buildStatCard(
            title: '物理内存',
            value: '${m.memory.usedMB} MB / ${m.memory.totalMB} MB',
            subtitle: '占比 ${(m.memory.usageRatio * 100).toStringAsFixed(1)}% | 可用 ${m.memory.availableMB} MB',
            color: const Color(0xFF3B82F6),
            icon: Icons.memory,
          ),
          _buildStatCard(
            title: '内核缓存结构',
            value: 'Slab: ${m.memory.slabMB} MB',
            subtitle: 'Dirty 脏页: ${m.memory.dirtyMB} MB',
            color: const Color(0xFF8B5CF6),
            icon: Icons.layers,
          ),
          _buildStatCard(
            title: '网络 TCP 连接状态',
            value: 'ESTAB: ${m.network.stateCount["ESTABLISHED"] ?? 0}',
            subtitle: 'TIME_WAIT: ${m.network.stateCount["TIME_WAIT"] ?? 0} | CLOSE_WAIT: ${m.network.stateCount["CLOSE_WAIT"] ?? 0}',
            color: const Color(0xFFF59E0B),
            icon: Icons.swap_calls,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: children
                .map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w))
                .toList(),
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: children,
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
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
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisksCard(List<DiskMetrics> disks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262B36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '磁盘存储与挂载点占用',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 12),
          ...disks.map((d) {
            final percent = (d.usageRatio * 100).toStringAsFixed(1);
            final isWarning = d.usageRatio > 0.85;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${d.filesystem}  ->  ${d.mountedOn}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      Text(
                        '${d.usedGB.toStringAsFixed(1)} GB / ${d.totalGB.toStringAsFixed(1)} GB ($percent%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isWarning ? const Color(0xFFF87171) : Colors.grey,
                          fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: d.usageRatio,
                      backgroundColor: const Color(0xFF2C3240),
                      valueColor: AlwaysStoppedAnimation(
                        isWarning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopProcessesCard(List<ProcessMetric> processes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262B36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 资源消耗进程',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(60),
              1: FlexColumnWidth(2),
              2: FixedColumnWidth(70),
              3: FixedColumnWidth(70),
            },
            children: [
              const TableRow(
                children: [
                  Text('PID', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('进程名称', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('CPU %', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('MEM %', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              ...processes.map(
                (p) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${p.pid}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${p.cpu.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${p.memory.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF34D399), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
