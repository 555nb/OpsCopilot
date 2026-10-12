package agent

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"opscopilot/internal/guardrail"
	"opscopilot/internal/probe"
)

type Config struct {
	BaseURL string `json:"base_url"`
	APIKey  string `json:"api_key"`
	Model   string `json:"model"`
}

type Message struct {
	Role      string                 `json:"role"`
	Content   string                 `json:"content"`
	Timestamp time.Time              `json:"timestamp"`
	Commands  []SuggestedCommand     `json:"commands,omitempty"`
}

type SuggestedCommand struct {
	Command     string                `json:"command"`
	Explanation string                `json:"explanation"`
	BlastRadius guardrail.BlastRadius `json:"blast_radius"`
}

type Agent struct {
	cfg    Config
	client *http.Client
}

func NewAgent(cfg Config) *Agent {
	if cfg.BaseURL == "" {
		cfg.BaseURL = "https://api.deepseek.com/v1"
	}
	if cfg.Model == "" {
		cfg.Model = "deepseek-chat"
	}
	return &Agent{
		cfg: cfg,
		client: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (a *Agent) ProcessQuery(userPrompt string, metrics *probe.SystemMetrics) (Message, error) {
	if a.cfg.APIKey == "" {
		return a.offlineReasoning(userPrompt, metrics), nil
	}

	systemPrompt := a.buildSystemPrompt(metrics)
	reqBody := map[string]interface{}{
		"model": a.cfg.Model,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userPrompt},
		},
		"temperature": 0.2,
	}

	payload, err := json.Marshal(reqBody)
	if err != nil {
		return a.offlineReasoning(userPrompt, metrics), nil
	}

	req, err := http.NewRequest("POST", a.cfg.BaseURL+"/chat/completions", bytes.NewBuffer(payload))
	if err != nil {
		return a.offlineReasoning(userPrompt, metrics), nil
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+a.cfg.APIKey)

	resp, err := a.client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		return a.offlineReasoning(userPrompt, metrics), nil
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	var apiResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(bodyBytes, &apiResp); err != nil || len(apiResp.Choices) == 0 {
		return a.offlineReasoning(userPrompt, metrics), nil
	}

	rawReply := apiResp.Choices[0].Message.Content
	return a.parseAndEnrichReply(rawReply), nil
}

func (a *Agent) buildSystemPrompt(metrics *probe.SystemMetrics) string {
	metricsJSON, _ := json.MarshalIndent(metrics, "", "  ")
	return fmt.Sprintf(`你是一名资深 Linux 运维专家与 SRE (Site Reliability Engineer)。
你的职责是协助运维工程师进行现场故障诊断、系统排查与脚本编写。
当前目标主机的实时底层探针数据如下：
%s

回答原则：
1. 语言自然、专业、直奔主题，严禁空洞的废话套话。
2. 给出诊断思路时，说明依据（如来自哪项指标）。
3. 如需给出建议命令，请以单个独立的 Markdown 代码块输出：
`+"```bash\n<命令>\n```"+`
4. 任何涉及系统变更的命令，必须指出风险点。`, string(metricsJSON))
}

func (a *Agent) parseAndEnrichReply(replyText string) Message {
	msg := Message{
		Role:      "assistant",
		Content:   replyText,
		Timestamp: time.Now(),
		Commands:  make([]SuggestedCommand, 0),
	}

	lines := strings.Split(replyText, "\n")
	inBashBlock := false
	var currentCmd strings.Builder

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "```bash") || strings.HasPrefix(trimmed, "```sh") {
			inBashBlock = true
			currentCmd.Reset()
			continue
		}
		if inBashBlock && strings.HasPrefix(trimmed, "```") {
			inBashBlock = false
			cmdStr := strings.TrimSpace(currentCmd.String())
			if cmdStr != "" {
				radius := guardrail.AnalyzeCommand(cmdStr)
				msg.Commands = append(msg.Commands, SuggestedCommand{
					Command:     cmdStr,
					Explanation: radius.Summary,
					BlastRadius: radius,
				})
			}
			continue
		}
		if inBashBlock {
			currentCmd.WriteString(line + "\n")
		}
	}

	return msg
}

func (a *Agent) offlineReasoning(userPrompt string, metrics *probe.SystemMetrics) Message {
	lower := strings.ToLower(userPrompt)
	var content strings.Builder
	suggestedCmds := make([]SuggestedCommand, 0)

	addCmd := func(cmd, expl string) {
		radius := guardrail.AnalyzeCommand(cmd)
		suggestedCmds = append(suggestedCmds, SuggestedCommand{
			Command:     cmd,
			Explanation: expl,
			BlastRadius: radius,
		})
	}

	if strings.Contains(lower, "cpu") || strings.Contains(lower, "负载") || strings.Contains(lower, "load") {
		content.WriteString(fmt.Sprintf("### 🎯 CPU 与系统负载诊断分析\n\n"))
		content.WriteString(fmt.Sprintf("- **当前负载趋势**：1m: `%.2f` | 5m: `%.2f` | 15m: `%.2f`\n", metrics.LoadAvg.Load1, metrics.LoadAvg.Load5, metrics.LoadAvg.Load15))
		content.WriteString("- **诊断结论**：当前任务调度队列处于平稳区间。如遇突发打满，需排查进程上下文切换频率及是否有多线程死锁。\n\n")
		content.WriteString("建议使用以下排查命令获取线程级明细：\n\n```bash\nps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu | head -n 10\n```\n")
		addCmd("ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu | head -n 10", "捕获消耗 CPU 最高的 Top 进程列表")
	} else if strings.Contains(lower, "内存") || strings.Contains(lower, "oom") || strings.Contains(lower, "mem") {
		content.WriteString(fmt.Sprintf("### 🎯 内存空间与 OOM 追踪分析\n\n"))
		content.WriteString(fmt.Sprintf("- **物理内存**：总计 `%d MB`，已用 `%d MB` (占比 `%.1f%%`)，可用 `%d MB`\n",
			metrics.Memory.TotalMB, metrics.Memory.UsedMB, metrics.Memory.UsageRatio*100, metrics.Memory.AvailableMB))
		content.WriteString(fmt.Sprintf("- **内核缓存结构**：Dirty 脏页 `%d MB`，Slab 占用 `%d MB`\n\n", metrics.Memory.DirtyMB, metrics.Memory.SlabMB))
		content.WriteString("建议排查内核 dmesg 中是否存在被 Kill 的进程，并检索已删除但未释放句柄的文件：\n\n```bash\ndmesg -T | grep -E -i 'oom|killed process' | tail -n 20\n```\n")
		addCmd("dmesg -T | grep -E -i 'oom|killed process' | tail -n 20", "检索历史内核 OOM 事件记录")
	} else if strings.Contains(lower, "网络") || strings.Contains(lower, "端口") || strings.Contains(lower, "tcp") {
		content.WriteString("### 🎯 网络协议栈与连接状态诊断\n\n")
		content.WriteString(fmt.Sprintf("- **TCP 连接分布**：ESTABLISHED: `%d` | TIME_WAIT: `%d` | CLOSE_WAIT: `%d`\n\n",
			metrics.Network.StateCount["ESTABLISHED"], metrics.Network.StateCount["TIME_WAIT"], metrics.Network.StateCount["CLOSE_WAIT"]))
		content.WriteString("推荐通过 `ss -tulpn` 检查本地服务监听状态与进程绑定：\n\n```bash\nss -tulpn\n```\n")
		addCmd("ss -tulpn", "列出当前所有监听端口及对应进程 PID")
	} else {
		content.WriteString(fmt.Sprintf("### 🎯 主机综合健康体检报告 (%s)\n\n", metrics.Hostname))
		content.WriteString(fmt.Sprintf("- 运行系统：%s\n- 1分钟负载：`%.2f`\n- 内存使用率：`%.1f%%`\n- 僵尸进程数：%d\n- 失败系统服务：%d\n\n",
			metrics.OS, metrics.LoadAvg.Load1, metrics.Memory.UsageRatio*100, metrics.ZombieProcesses, len(metrics.FailedServices)))
		content.WriteString("如需针对某项指标深入定位，可直接询问（如：“为什么磁盘满了”、“排查网络连接堆积”）。")
	}

	return Message{
		Role:      "assistant",
		Content:   content.String(),
		Timestamp: time.Now(),
		Commands:  suggestedCmds,
	}
}
