package guardrail

import (
	"fmt"
	"regexp"
	"strings"
)

type RiskLevel string

const (
	RiskSafe   RiskLevel = "SAFE"
	RiskMedium RiskLevel = "MEDIUM"
	RiskHigh   RiskLevel = "HIGH"
	RiskBlock  RiskLevel = "BLOCK"
)

type BlastRadius struct {
	Level             RiskLevel `json:"level"`
	Score             int       `json:"score"`
	Summary           string    `json:"summary"`
	IsDestructive     bool      `json:"is_destructive"`
	AffectsNetwork    bool      `json:"affects_network"`
	AffectsCoreDaemon bool      `json:"affects_core_daemon"`
	RequiresApproval  bool      `json:"requires_approval"`
	Warnings          []string  `json:"warnings"`
	PrecheckCommand   string    `json:"precheck_command"`
	RollbackCommand   string    `json:"rollback_command"`
}

type Rule struct {
	Pattern     *regexp.Regexp
	Level       RiskLevel
	Description string
	Precheck    string
	Rollback    string
}

var blockedPatterns = []Rule{
	{
		Pattern:     regexp.MustCompile(`(?i)\brm\s+-[rRfF]*\s+/(?:\s|$|\*)`),
		Level:       RiskBlock,
		Description: "检测到根目录递归删除高危命令，系统底层硬拦截",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\bmkfs\b|\bfdisk\b|\bparted\b`),
		Level:       RiskBlock,
		Description: "底层块设备格式化/重新分区高危操作",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\bdd\s+if=.*of=/dev/`),
		Level:       RiskBlock,
		Description: "底层裸设备覆写高危操作",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)>\s*/dev/sd[a-z]|>\s*/dev/nvme`),
		Level:       RiskBlock,
		Description: "向物理存储设备直写覆盖，将造成不可逆分区损坏",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\bchmod\s+(-R\s+)?777\s+/`),
		Level:       RiskBlock,
		Description: "根目录全量赋予 777 权限，将直接击垮 Linux 权限体系与 SSH 登录",
	},
}

var highRiskPatterns = []Rule{
	{
		Pattern:     regexp.MustCompile(`(?i)\biptables\s+-F|\bufw\s+disable|\bfirewall-cmd\s+--reload`),
		Level:       RiskHigh,
		Description: "清空或变更防火墙策略，可能导致服务端口直接暴露或断开管理员连接",
		Precheck:    "iptables-save > /tmp/iptables_backup_$(date +%s).rules",
		Rollback:    "iptables-restore < /tmp/iptables_backup_*.rules",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\bkill\s+-9\s+1\b|\bpkill\s+-9\s+systemd`),
		Level:       RiskHigh,
		Description: "尝试强制杀死 PID 1 (Init/Systemd)，将直接导致内核崩溃(Kernel Panic)",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\breboot\b|\bshutdown\b|\bpoweroff\b|\binit\s+0`),
		Level:       RiskHigh,
		Description: "节点重启/关机操作，将导致当前节点所有容器与业务中断",
		Precheck:    "uptime && who",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\bsystemctl\s+(stop|disable)\s+(sshd|docker|containerd|kubelet)`),
		Level:       RiskHigh,
		Description: "停止关键基础设施守护进程，可能导致节点脱管或集群失联",
		Rollback:    "systemctl start <service>",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\brm\s+-[rRfF]*\s+/etc`),
		Level:       RiskHigh,
		Description: "删除系统核心配置文件目录",
		Precheck:    "tar -czf /tmp/etc_backup_$(date +%s).tar.gz /etc",
		Rollback:    "tar -xzf /tmp/etc_backup_*.tar.gz -C /",
	},
}

var mediumRiskPatterns = []Rule{
	{
		Pattern:     regexp.MustCompile(`(?i)\bsystemctl\s+restart\s+([a-zA-Z0-9_\-\.]+)`),
		Level:       RiskMedium,
		Description: "重启系统服务，会产生短暂连接中断",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\brm\s+-[rRfF]*`),
		Level:       RiskMedium,
		Description: "执行文件递归删除操作",
	},
	{
		Pattern:     regexp.MustCompile(`(?i)\bsed\s+-i`),
		Level:       RiskMedium,
		Description: "文件就地替换修改操作",
		Precheck:    "cp target_file target_file.bak_$(date +%s)",
		Rollback:    "mv target_file.bak_* target_file",
	},
}

func AnalyzeCommand(cmd string) BlastRadius {
	trimmed := strings.TrimSpace(cmd)
	result := BlastRadius{
		Level:            RiskSafe,
		Score:            0,
		Summary:          "只读或安全无害操作，可直接执行",
		Warnings:         make([]string, 0),
		RequiresApproval: false,
	}

	for _, rule := range blockedPatterns {
		if rule.Pattern.MatchString(trimmed) {
			result.Level = RiskBlock
			result.Score = 100
			result.IsDestructive = true
			result.RequiresApproval = false
			result.Summary = fmt.Sprintf("【危险阻断】%s", rule.Description)
			result.Warnings = append(result.Warnings, rule.Description)
			return result
		}
	}

	for _, rule := range highRiskPatterns {
		if rule.Pattern.MatchString(trimmed) {
			result.Level = RiskHigh
			result.Score = 80
			result.IsDestructive = true
			result.RequiresApproval = true
			result.Summary = fmt.Sprintf("【高危变更】%s", rule.Description)
			result.Warnings = append(result.Warnings, rule.Description)
			if strings.Contains(trimmed, "iptables") || strings.Contains(trimmed, "ufw") {
				result.AffectsNetwork = true
			}
			if strings.Contains(trimmed, "sshd") || strings.Contains(trimmed, "systemd") || strings.Contains(trimmed, "kubelet") {
				result.AffectsCoreDaemon = true
			}
			result.PrecheckCommand = rule.Precheck
			result.RollbackCommand = rule.Rollback
			return result
		}
	}

	for _, rule := range mediumRiskPatterns {
		if rule.Pattern.MatchString(trimmed) {
			result.Level = RiskMedium
			result.Score = 40
			result.IsDestructive = false
			result.RequiresApproval = true
			result.Summary = fmt.Sprintf("【中危状态变更】%s", rule.Description)
			result.Warnings = append(result.Warnings, rule.Description)
			result.PrecheckCommand = rule.Precheck
			result.RollbackCommand = rule.Rollback
			return result
		}
	}

	return result
}
