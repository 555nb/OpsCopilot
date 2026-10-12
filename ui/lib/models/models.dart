class SystemMetrics {
  final String os;
  final String hostname;
  final double cpuUsage;
  final LoadAverage loadAvg;
  final MemoryMetrics memory;
  final List<DiskMetrics> disks;
  final NetworkMetrics network;
  final List<String> failedServices;
  final int zombieProcesses;
  final List<String> oomEvents;
  final List<ProcessMetric> topProcesses;

  SystemMetrics({
    required this.os,
    required this.hostname,
    required this.cpuUsage,
    required this.loadAvg,
    required this.memory,
    required this.disks,
    required this.network,
    required this.failedServices,
    required this.zombieProcesses,
    required this.oomEvents,
    required this.topProcesses,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      os: json['os'] ?? 'linux',
      hostname: json['hostname'] ?? 'localhost',
      cpuUsage: (json['cpu_usage'] as num?)?.toDouble() ?? 0.0,
      loadAvg: LoadAverage.fromJson(json['load_avg'] ?? {}),
      memory: MemoryMetrics.fromJson(json['memory'] ?? {}),
      disks: (json['disks'] as List? ?? [])
          .map((d) => DiskMetrics.fromJson(d))
          .toList(),
      network: NetworkMetrics.fromJson(json['network'] ?? {}),
      failedServices: List<String>.from(json['failed_services'] ?? []),
      zombieProcesses: json['zombie_processes'] ?? 0,
      oomEvents: List<String>.from(json['oom_events'] ?? []),
      topProcesses: (json['top_processes'] as List? ?? [])
          .map((p) => ProcessMetric.fromJson(p))
          .toList(),
    );
  }
}

class LoadAverage {
  final double load1;
  final double load5;
  final double load15;

  LoadAverage({required this.load1, required this.load5, required this.load15});

  factory LoadAverage.fromJson(Map<String, dynamic> json) {
    return LoadAverage(
      load1: (json['load_1'] as num?)?.toDouble() ?? 0.0,
      load5: (json['load_5'] as num?)?.toDouble() ?? 0.0,
      load15: (json['load_15'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MemoryMetrics {
  final int totalMB;
  final int usedMB;
  final int availableMB;
  final double usageRatio;
  final int dirtyMB;
  final int slabMB;

  MemoryMetrics({
    required this.totalMB,
    required this.usedMB,
    required this.availableMB,
    required this.usageRatio,
    required this.dirtyMB,
    required this.slabMB,
  });

  factory MemoryMetrics.fromJson(Map<String, dynamic> json) {
    return MemoryMetrics(
      totalMB: json['total_mb'] ?? 0,
      usedMB: json['used_mb'] ?? 0,
      availableMB: json['available_mb'] ?? 0,
      usageRatio: (json['usage_ratio'] as num?)?.toDouble() ?? 0.0,
      dirtyMB: json['dirty_mb'] ?? 0,
      slabMB: json['slab_mb'] ?? 0,
    );
  }
}

class DiskMetrics {
  final String filesystem;
  final String mountedOn;
  final double totalGB;
  final double usedGB;
  final double usageRatio;

  DiskMetrics({
    required this.filesystem,
    required this.mountedOn,
    required this.totalGB,
    required this.usedGB,
    required this.usageRatio,
  });

  factory DiskMetrics.fromJson(Map<String, dynamic> json) {
    return DiskMetrics(
      filesystem: json['filesystem'] ?? '',
      mountedOn: json['mounted_on'] ?? '',
      totalGB: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGB: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      usageRatio: (json['usage_ratio'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NetworkMetrics {
  final int totalConnections;
  final Map<String, int> stateCount;
  final List<int> listenPorts;

  NetworkMetrics({
    required this.totalConnections,
    required this.stateCount,
    required this.listenPorts,
  });

  factory NetworkMetrics.fromJson(Map<String, dynamic> json) {
    return NetworkMetrics(
      totalConnections: json['total_connections'] ?? 0,
      stateCount: Map<String, int>.from(json['state_count'] ?? {}),
      listenPorts: List<int>.from(json['listen_ports'] ?? []),
    );
  }
}

class ProcessMetric {
  final int pid;
  final String name;
  final double cpu;
  final double memory;
  final String command;

  ProcessMetric({
    required this.pid,
    required this.name,
    required this.cpu,
    required this.memory,
    required this.command,
  });

  factory ProcessMetric.fromJson(Map<String, dynamic> json) {
    return ProcessMetric(
      pid: json['pid'] ?? 0,
      name: json['name'] ?? '',
      cpu: (json['cpu'] as num?)?.toDouble() ?? 0.0,
      memory: (json['memory'] as num?)?.toDouble() ?? 0.0,
      command: json['command'] ?? '',
    );
  }
}

class BlastRadius {
  final String level; // SAFE, MEDIUM, HIGH, BLOCK
  final int score;
  final String summary;
  final bool isDestructive;
  final bool requiresApproval;
  final List<String> warnings;
  final String precheckCommand;
  final String rollbackCommand;

  BlastRadius({
    required this.level,
    required this.score,
    required this.summary,
    required this.isDestructive,
    required this.requiresApproval,
    required this.warnings,
    required this.precheckCommand,
    required this.rollbackCommand,
  });

  factory BlastRadius.fromJson(Map<String, dynamic> json) {
    return BlastRadius(
      level: json['level'] ?? 'SAFE',
      score: json['score'] ?? 0,
      summary: json['summary'] ?? '',
      isDestructive: json['is_destructive'] ?? false,
      requiresApproval: json['requires_approval'] ?? false,
      warnings: List<String>.from(json['warnings'] ?? []),
      precheckCommand: json['precheck_command'] ?? '',
      rollbackCommand: json['rollback_command'] ?? '',
    );
  }
}

class SuggestedCommand {
  final String command;
  final String explanation;
  final BlastRadius blastRadius;

  SuggestedCommand({
    required this.command,
    required this.explanation,
    required this.blastRadius,
  });

  factory SuggestedCommand.fromJson(Map<String, dynamic> json) {
    return SuggestedCommand(
      command: json['command'] ?? '',
      explanation: json['explanation'] ?? '',
      blastRadius: BlastRadius.fromJson(json['blast_radius'] ?? {}),
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final List<SuggestedCommand> commands;

  ChatMessage({
    required this.role,
    required this.content,
    this.commands = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      commands: (json['commands'] as List? ?? [])
          .map((c) => SuggestedCommand.fromJson(c))
          .toList(),
    );
  }
}

class SOPPlaybook {
  final String id;
  final String category;
  final String title;
  final String description;
  final String severity;
  final List<SOPStep> steps;

  SOPPlaybook({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    required this.steps,
  });

  factory SOPPlaybook.fromJson(Map<String, dynamic> json) {
    return SOPPlaybook(
      id: json['id'] ?? '',
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'LOW',
      steps: (json['steps'] as List? ?? [])
          .map((s) => SOPStep.fromJson(s))
          .toList(),
    );
  }
}

class SOPStep {
  final int stepNumber;
  final String title;
  final String description;
  final String command;
  final String explanation;
  final bool isSafe;

  SOPStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.command,
    required this.explanation,
    required this.isSafe,
  });

  factory SOPStep.fromJson(Map<String, dynamic> json) {
    return SOPStep(
      stepNumber: json['step_number'] ?? 1,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      command: json['command'] ?? '',
      explanation: json['explanation'] ?? '',
      isSafe: json['is_safe'] ?? true,
    );
  }
}

class RemoteHost {
  final String id;
  final String name;
  final String host;
  final int port;
  final String user;
  final String status;
  final String lastPing;

  RemoteHost({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.user,
    required this.status,
    required this.lastPing,
  });

  factory RemoteHost.fromJson(Map<String, dynamic> json) {
    return RemoteHost(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      host: json['host'] ?? '',
      port: json['port'] ?? 22,
      user: json['user'] ?? 'root',
      status: json['status'] ?? 'unknown',
      lastPing: json['last_ping'] ?? '',
    );
  }
}

class ExecutionResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final int durationMs;
  final BlastRadius blastRadius;

  ExecutionResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.durationMs,
    required this.blastRadius,
  });

  factory ExecutionResult.fromJson(Map<String, dynamic> json) {
    return ExecutionResult(
      stdout: json['stdout'] ?? '',
      stderr: json['stderr'] ?? '',
      exitCode: json['exit_code'] ?? 0,
      durationMs: json['duration_ms'] ?? 0,
      blastRadius: BlastRadius.fromJson(json['blast_radius'] ?? {}),
    );
  }
}
