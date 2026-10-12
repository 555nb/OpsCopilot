import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CopilotView extends StatefulWidget {
  final ApiService apiService;
  final String? initialPrompt;

  const CopilotView({
    super.key,
    required this.apiService,
    this.initialPrompt,
  });

  @override
  State<CopilotView> createState() => _CopilotViewState();
}

class _CopilotViewState extends State<CopilotView> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      role: 'assistant',
      content: '你好！我是 **OpsCopilot**，你的工业级智能运维副驾。\n\n我已接入当前节点的底层探针与安全风控系统。你可以随时询问排障思路、生成运维脚本，或针对高负载、OOM、端口瓶颈进行定向诊断。',
      commands: [
        SuggestedCommand(
          command: 'opscopilot doctor',
          explanation: '一键运行本地 Linux 系统底层健康体检',
          blastRadius: BlastRadius(
            level: 'SAFE',
            score: 0,
            summary: '只读指标探针采集，安全无害',
            isDestructive: false,
            requiresApproval: false,
            warnings: [],
            precheckCommand: '',
            rollbackCommand: '',
          ),
        ),
      ],
    ));

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendPrompt(widget.initialPrompt!);
      });
    }
  }

  Future<void> _sendPrompt(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _inputController.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: query));
      _isSending = true;
    });

    final reply = await widget.apiService.sendChat(query);
    if (mounted) {
      setState(() {
        _isSending = false;
        if (reply != null) {
          _messages.add(reply);
        } else {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: '⚠️ 与 OpsCopilot 后端连接超时，请确认核心服务已正常启动。',
          ));
        }
      });
    }
  }

  void _executeCommandSafely(SuggestedCommand cmdItem) async {
    final radius = cmdItem.blastRadius;
    if (radius.level == 'BLOCK') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('系统底层安全拦截: ${radius.summary}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (radius.requiresApproval) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E222B),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('风控二次确认 (${radius.level})', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('待执行命令:\n${cmdItem.command}', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              Text('风险概要: ${radius.summary}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
              if (radius.rollbackCommand.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('回滚建议: ${radius.rollbackCommand}', style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('放弃', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('授权执行', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在执行命令...'), duration: Duration(seconds: 1)),
    );

    final res = await widget.apiService.executeCommand('local', cmdItem.command);
    if (!mounted) return;

    if (res != null) {
      _showResultModal(cmdItem.command, res);
    }
  }

  void _showResultModal(String cmd, ExecutionResult res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181B22),
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      res.exitCode == 0 ? Icons.check_circle : Icons.error,
                      color: res.exitCode == 0 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '退出码: ${res.exitCode} (${res.durationMs}ms)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1117),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                cmd,
                style: const TextStyle(color: Color(0xFF60A5FA), fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text('终端输出 (STDOUT / STDERR):', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1117),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF262B36)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    res.stdout.isNotEmpty ? res.stdout : (res.stderr.isNotEmpty ? res.stderr : '(无文本输出)'),
                    style: TextStyle(
                      color: res.exitCode == 0 ? Colors.white70 : const Color(0xFFF87171),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (ctx, idx) => _buildMessageBubble(_messages[idx]),
          ),
        ),
        if (_isSending)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
              minHeight: 2,
            ),
          ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.psychology, color: Color(0xFF60A5FA), size: 18),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2563EB) : const Color(0xFF181B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isUser ? const Color(0xFF3B82F6) : const Color(0xFF262B36),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    msg.content,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                  ),
                  if (msg.commands.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...msg.commands.map((cmd) => _buildCommandCard(cmd)),
                  ],
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildCommandCard(SuggestedCommand cmdItem) {
    final radius = cmdItem.blastRadius;
    Color badgeColor;
    switch (radius.level) {
      case 'BLOCK':
        badgeColor = const Color(0xFFEF4444);
        break;
      case 'HIGH':
        badgeColor = const Color(0xFFF97316);
        break;
      case 'MEDIUM':
        badgeColor = const Color(0xFFFBBF24);
        break;
      default:
        badgeColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF262B36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(
                  '${radius.level} (风险: ${radius.score})',
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                cmdItem.explanation,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            cmdItem.command,
            style: const TextStyle(
              color: Color(0xFF93C5FD),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          if (radius.rollbackCommand.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.undo, color: Colors.grey, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '回滚: ${radius.rollbackCommand}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cmdItem.command));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制命令到剪贴板'), duration: Duration(seconds: 1)),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('复制', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: radius.level == 'BLOCK'
                      ? Colors.grey
                      : (radius.requiresApproval ? const Color(0xFFF97316) : const Color(0xFF10B981)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: radius.level == 'BLOCK' ? null : () => _executeCommandSafely(cmdItem),
                icon: Icon(radius.requiresApproval ? Icons.shield : Icons.play_arrow, size: 14),
                label: Text(
                  radius.level == 'BLOCK' ? '禁止执行' : (radius.requiresApproval ? '审批执行' : '安全运行'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF181B22),
        border: Border(top: BorderSide(color: Color(0xFF262B36))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: '输入运维问题（如：“排查 TCP 连接暴涨”、“检查 80 端口占用”）...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              onSubmitted: _sendPrompt,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF60A5FA), size: 20),
            onPressed: () => _sendPrompt(_inputController.text),
          ),
        ],
      ),
    );
  }
}
