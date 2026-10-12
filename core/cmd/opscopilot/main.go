package main

import (
	"flag"
	"fmt"
	"os"

	"opscopilot/internal/agent"
	"opscopilot/internal/guardrail"
	"opscopilot/internal/probe"
	"opscopilot/internal/server"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		return
	}

	switch os.Args[1] {
	case "serve":
		serveCmd := flag.NewFlagSet("serve", flag.ExitOnError)
		port := serveCmd.Int("port", 8080, "HTTP 服务监听端口")
		apiKey := serveCmd.String("api-key", os.Getenv("OPS_API_KEY"), "大模型 API Key (可选)")
		baseURL := serveCmd.String("base-url", os.Getenv("OPS_BASE_URL"), "大模型 API Base URL")
		model := serveCmd.String("model", "deepseek-chat", "大模型名称")
		serveCmd.Parse(os.Args[2:])

		ag := agent.NewAgent(agent.Config{
			BaseURL: *baseURL,
			APIKey:  *apiKey,
			Model:   *model,
		})
		srv := server.NewServer(*port, ag)
		if err := srv.Start(); err != nil {
			fmt.Printf("服务启动失败: %v\n", err)
			os.Exit(1)
		}

	case "doctor":
		runDoctor()

	case "ask":
		if len(os.Args) < 3 {
			fmt.Println("用法: opscopilot ask \"你的运维问题\"")
			os.Exit(1)
		}
		runAsk(os.Args[2])

	case "check":
		if len(os.Args) < 3 {
			fmt.Println("用法: opscopilot check \"待检测命令\"")
			os.Exit(1)
		}
		runCheck(os.Args[2])

	default:
		printUsage()
	}
}

func printUsage() {
	fmt.Println(`OpsCopilot - 面向生产级 SRE / Linux 运维工程师的智能副驾

子命令:
  serve   启动 API 与后台守护进程，供跨平台 UI 客户端连接
          参数: --port 8080 [--api-key xxx] [--base-url url]
  doctor  一键系统底层健康体检（检查 CPU负载/内存分布/OOM/磁盘/网络）
  ask     终端快速提问与智能诊断 (例如: opscopilot ask "排查高负载")
  check   检测任意运维命令的爆炸半径与安全风控等级`)
}

func runDoctor() {
	fmt.Println("🔍 正在采集系统底层原子指标...")
	m, err := probe.CollectMetrics()
	if err != nil {
		fmt.Printf("采集失败: %v\n", err)
		return
	}

	fmt.Printf("\n===== 🎯 OpsCopilot 主机健康体检报告 (%s) =====\n", m.Hostname)
	fmt.Printf("操作系统:   %s\n", m.OS)
	fmt.Printf("1/5/15m负载: %.2f / %.2f / %.2f\n", m.LoadAvg.Load1, m.LoadAvg.Load5, m.LoadAvg.Load15)
	fmt.Printf("物理内存:   总计 %d MB | 已用 %d MB (%.1f%%) | 可用 %d MB\n",
		m.Memory.TotalMB, m.Memory.UsedMB, m.Memory.UsageRatio*100, m.Memory.AvailableMB)
	fmt.Printf("内核缓存:   Dirty脏页 %d MB | Slab结构 %d MB\n", m.Memory.DirtyMB, m.Memory.SlabMB)
	fmt.Printf("僵尸进程数: %d\n", m.ZombieProcesses)
	fmt.Printf("失败服务数: %d\n", len(m.FailedServices))

	if len(m.OOMEvents) > 0 {
		fmt.Printf("\n⚠️ 发现 %d 条历史 OOM 强杀事件:\n", len(m.OOMEvents))
		for _, e := range m.OOMEvents {
			fmt.Printf("  - %s\n", e)
		}
	} else {
		fmt.Println("✅ 近期无内核 OOM-killer 记录")
	}

	fmt.Println("\n网络连接状态:")
	for state, count := range m.Network.StateCount {
		fmt.Printf("  - %-12s: %d\n", state, count)
	}

	fmt.Println("\n磁盘挂载与使用:")
	for _, d := range m.Disks {
		fmt.Printf("  - %-15s -> %-10s: %.1f GB / %.1f GB (%.1f%%)\n",
			d.Filesystem, d.MountedOn, d.UsedGB, d.TotalGB, d.UsageRatio*100)
	}
	fmt.Println("==================================================")
}

func runAsk(prompt string) {
	m, _ := probe.CollectMetrics()
	ag := agent.NewAgent(agent.Config{
		APIKey: os.Getenv("OPS_API_KEY"),
	})

	reply, err := ag.ProcessQuery(prompt, m)
	if err != nil {
		fmt.Printf("处理失败: %v\n", err)
		return
	}

	fmt.Println(reply.Content)
	if len(reply.Commands) > 0 {
		fmt.Println("\n[安全护栏与推荐命令]")
		for i, c := range reply.Commands {
			fmt.Printf("\n%d. 命令: %s\n", i+1, c.Command)
			fmt.Printf("   安全评级: [%s] (危险分: %d)\n", c.BlastRadius.Level, c.BlastRadius.Score)
			fmt.Printf("   影响范围: %s\n", c.BlastRadius.Summary)
			if c.BlastRadius.RollbackCommand != "" {
				fmt.Printf("   推荐回滚: %s\n", c.BlastRadius.RollbackCommand)
			}
		}
	}
}

func runCheck(cmdStr string) {
	radius := guardrail.AnalyzeCommand(cmdStr)
	fmt.Printf("\n待审计命令: %s\n", cmdStr)
	fmt.Printf("安全评级:   [%s]\n", radius.Level)
	fmt.Printf("危险指数:   %d / 100\n", radius.Score)
	fmt.Printf("评估概要:   %s\n", radius.Summary)
	if radius.PrecheckCommand != "" {
		fmt.Printf("前置备份:   %s\n", radius.PrecheckCommand)
	}
	if radius.RollbackCommand != "" {
		fmt.Printf("回滚指令:   %s\n", radius.RollbackCommand)
	}
	if radius.RequiresApproval {
		fmt.Println("风控策略:   【强制人在回路】生产环境必须经值班人员审批后方可执行")
	}
}
