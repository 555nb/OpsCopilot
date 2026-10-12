package remote

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"opscopilot/internal/guardrail"
)

type RemoteHost struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Host     string `json:"host"`
	Port     int    `json:"port"`
	User     string `json:"user"`
	KeyPath  string `json:"key_path,omitempty"`
	Status   string `json:"status"` // online, offline, unreachable
	LastPing string `json:"last_ping"`
}

type CommandExecutionResult struct {
	HostID      string                `json:"host_id"`
	Command     string                `json:"command"`
	Stdout      string                `json:"stdout"`
	Stderr      string                `json:"stderr"`
	ExitCode    int                   `json:"exit_code"`
	DurationMs  int64                 `json:"duration_ms"`
	BlastRadius guardrail.BlastRadius `json:"blast_radius"`
}

type HostManager struct {
	hosts map[string]RemoteHost
}

func NewHostManager() *HostManager {
	mgr := &HostManager{
		hosts: make(map[string]RemoteHost),
	}
	mgr.hosts["local"] = RemoteHost{
		ID:       "local",
		Name:     "当前节点 (Localhost)",
		Host:     "127.0.0.1",
		Port:     22,
		User:     "current",
		Status:   "online",
		LastPing: time.Now().Format("15:04:05"),
	}
	return mgr
}

func (m *HostManager) ListHosts() []RemoteHost {
	list := make([]RemoteHost, 0, len(m.hosts))
	for _, h := range m.hosts {
		list = append(list, h)
	}
	return list
}

func (m *HostManager) AddHost(h RemoteHost) {
	if h.Port == 0 {
		h.Port = 22
	}
	if h.User == "" {
		h.User = "root"
	}
	h.Status = "online"
	h.LastPing = time.Now().Format("15:04:05")
	m.hosts[h.ID] = h
}

func (m *HostManager) ExecuteCommand(ctx context.Context, hostID, cmdStr string) (CommandExecutionResult, error) {
	radius := guardrail.AnalyzeCommand(cmdStr)
	result := CommandExecutionResult{
		HostID:      hostID,
		Command:     cmdStr,
		BlastRadius: radius,
	}

	if radius.Level == guardrail.RiskBlock {
		result.ExitCode = 126
		result.Stderr = fmt.Sprintf("【安全拦截】命令被 OpsCopilot 安全护栏拦截: %s", radius.Summary)
		return result, nil
	}

	start := time.Now()
	var outBuf, errBuf bytes.Buffer

	h, ok := m.hosts[hostID]
	if !ok || hostID == "local" {
		var cmd *exec.Cmd
		if strings.Contains(strings.ToLower(cmdStr), "dir") || strings.Contains(strings.ToLower(cmdStr), "echo") {
			cmd = exec.CommandContext(ctx, "cmd", "/C", cmdStr)
		} else {
			cmd = exec.CommandContext(ctx, "bash", "-c", cmdStr)
		}
		cmd.Stdout = &outBuf
		cmd.Stderr = &errBuf
		err := cmd.Run()
		result.DurationMs = time.Since(start).Milliseconds()
		result.Stdout = outBuf.String()
		result.Stderr = errBuf.String()
		if err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				result.ExitCode = exitErr.ExitCode()
			} else {
				result.ExitCode = 1
			}
		}
		return result, nil
	}

	sshArgs := []string{
		"-o", "StrictHostKeyChecking=no",
		"-o", "ConnectTimeout=5",
		"-p", fmt.Sprintf("%d", h.Port),
	}
	if h.KeyPath != "" {
		sshArgs = append(sshArgs, "-i", h.KeyPath)
	}
	sshArgs = append(sshArgs, fmt.Sprintf("%s@%s", h.User, h.Host), cmdStr)

	cmd := exec.CommandContext(ctx, "ssh", sshArgs...)
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf
	err := cmd.Run()

	result.DurationMs = time.Since(start).Milliseconds()
	result.Stdout = outBuf.String()
	result.Stderr = errBuf.String()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exitErr.ExitCode()
		} else {
			result.ExitCode = 1
		}
	}

	return result, nil
}
