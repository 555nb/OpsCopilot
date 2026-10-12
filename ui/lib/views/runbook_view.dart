import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class RunbookView extends StatefulWidget {
  final ApiService apiService;

  const RunbookView({super.key, required this.apiService});

  @override
  State<RunbookView> createState() => _RunbookViewState();
}

class _RunbookViewState extends State<RunbookView> {
  List<SOPPlaybook> _playbooks = [];
  bool _isLoading = true;
  SOPPlaybook? _selectedPlaybook;

  @override
  void initState() {
    super.initState();
    _loadRunbooks();
  }

  Future<void> _loadRunbooks() async {
    setState(() => _isLoading = true);
    final list = await widget.apiService.getRunbooks();
    if (mounted) {
      setState(() {
        _playbooks = list;
        _isLoading = false;
        if (list.isNotEmpty && _selectedPlaybook == null) {
          _selectedPlaybook = list.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_playbooks.isEmpty) {
      return const Center(
        child: Text('暂无可用的 SRE 排障预案库', style: TextStyle(color: Colors.grey)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        if (isNarrow) {
          return _selectedPlaybook == null
              ? _buildPlaybookList()
              : _buildPlaybookDetail(_selectedPlaybook!, canBack: true);
        }

        return Row(
          children: [
            SizedBox(
              width: 320,
              child: _buildPlaybookList(),
            ),
            const VerticalDivider(width: 1, color: Color(0xFF262B36)),
            Expanded(
              child: _selectedPlaybook != null
                  ? _buildPlaybookDetail(_selectedPlaybook!, canBack: false)
                  : const Center(child: Text('请选择排障预案', style: TextStyle(color: Colors.grey))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaybookList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _playbooks.length,
      itemBuilder: (ctx, idx) {
        final p = _playbooks[idx];
        final isSelected = p.id == _selectedPlaybook?.id;
        return Card(
          color: isSelected ? const Color(0xFF1E2638) : const Color(0xFF181B22),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF262B36),
            ),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(
              p.title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  p.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.severity == 'CRITICAL' ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.category,
                    style: TextStyle(
                      color: p.severity == 'CRITICAL' ? Colors.redAccent : Colors.orangeAccent,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() => _selectedPlaybook = p);
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaybookDetail(SOPPlaybook p, {required bool canBack}) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedPlaybook = null),
              )
            : null,
        title: Text(p.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF262B36)),
            ),
            child: Text(
              '排障目标: ${p.description}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          const Text('标准排查流水线 (SOP Steps):', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...p.steps.map((step) => _buildStepCard(step)),
        ],
      ),
    );
  }

  Widget _buildStepCard(SOPStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262B36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(step.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1117),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF262B36)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    step.command,
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: step.command));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制排查命令'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '💡 诊断要点: ${step.explanation}',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
