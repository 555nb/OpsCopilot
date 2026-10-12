package runbook

type SOPStep struct {
	StepNumber  int    `json:"step_number"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Command     string `json:"command"`
	Explanation string `json:"explanation"`
	IsSafe      bool   `json:"is_safe"`
}

type SOPPlaybook struct {
	ID          string    `json:"id"`
	Category    string    `json:"category"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Severity    string    `json:"severity"`
	Steps       []SOPStep `json:"steps"`
}

func GetAllPlaybooks() []SOPPlaybook {
	return []SOPPlaybook{
		{
			ID:          "sop-cpu-load",
			Category:    "CPU & 负载",
			Title:       "CPU 100% 突发异常根因排查",
			Description: "定位高负载来源：区分用户态死循环、内核态锁竞争、软中断风暴或 IO 等待。",
			Severity:    "CRITICAL",
			Steps: []SOPStep{
				{
					StepNumber:  1,
					Title:       "检查系统平均负载与状态概览",
					Description: "比对 1/5/15 分钟负载趋势与 CPU 核心数关系",
					Command:     "uptime && cat /proc/loadavg",
					Explanation: "若 load1 远大于 CPU 核数，表明任务队列严重堆积",
					IsSafe:      true,
				},
				{
					StepNumber:  2,
					Title:       "捕获消耗 CPU 最高的 Top 进程",
					Description: "以批处理模式捕获瞬间消耗最大的进程及所属用户",
					Command:     "ps -eo pid,ppid,user,%cpu,%mem,comm --sort=-%cpu | head -n 10",
					Explanation: "快速锁定目标 PID 与可疑二进制",
					IsSafe:      true,
				},
				{
					StepNumber:  3,
					Title:       "展开目标进程内部的高消耗线程",
					Description: "查看目标进程多线程调度明细",
					Command:     "top -H -b -n 1 | head -n 25",
					Explanation: "定位是特定工作线程狂转还是全线程并发打满",
					IsSafe:      true,
				},
			},
		},
		{
			ID:          "sop-oom-leak",
			Category:    "内存 & OOM",
			Title:       "内存泄漏与内核 OOM Killer 追踪",
			Description: "排查进程内存泄露、Slab 占用异常与内核强杀事件记录。",
			Severity:    "CRITICAL",
			Steps: []SOPStep{
				{
					StepNumber:  1,
					Title:       "检索内核 dmesg 中的 OOM 事件日志",
					Description: "提取内核 Out of memory 与 killed process 现场",
					Command:     "dmesg -T | grep -E -i 'oom|out of memory|killed process' | tail -n 20",
					Explanation: "确认哪个服务在何时触发了内核 OOM-killer",
					IsSafe:      true,
				},
				{
					StepNumber:  2,
					Title:       "深度剖析 /proc/meminfo 关键内存分布",
					Description: "查看可用内存、Dirty 脏页与 Slab 结构",
					Command:     "grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|Slab|Dirty' /proc/meminfo",
					Explanation: "排除内核 Slab 泄露或脏页刷盘阻塞导致的可用内存不足",
					IsSafe:      true,
				},
				{
					StepNumber:  3,
					Title:       "排查已删除但句柄未释放的幽灵文件",
					Description: "定位占用大量磁盘和缓存却在文件系统中找不到的文件",
					Command:     "lsof +L1 2>/dev/null | head -n 15",
					Explanation: "常发生于日志文件被直接 rm 但进程未重启，导致句柄死锁",
					IsSafe:      true,
				},
			},
		},
		{
			ID:          "sop-disk-exhaustion",
			Category:    "存储 & 磁盘",
			Title:       "磁盘空间与 Inode 耗尽秒级清障",
			Description: "根治 No space left on device 错误，排查空间与 Inode 节点耗尽。",
			Severity:    "HIGH",
			Steps: []SOPStep{
				{
					StepNumber:  1,
					Title:       "比对块容量与 Inode 索引节点双重指标",
					Description: "判断是物理容量写满还是海量小文件耗光了 Inode",
					Command:     "df -h && df -i",
					Explanation: "如果 df -h 有余量但 df -i 达到 100%，则是小文件堆积导致",
					IsSafe:      true,
				},
				{
					StepNumber:  2,
					Title:       "根分区大文件目录快速定位",
					Description: "跨文件系统层级查找占用空间前 8 的顶层目录",
					Command:     "du -ahx / 2>/dev/null | sort -rh | head -n 10",
					Explanation: "精准定位爆满的日志目录或数据目录",
					IsSafe:      true,
				},
			},
		},
		{
			ID:          "sop-network-timewait",
			Category:    "网络 & 协议栈",
			Title:       "TCP 连接暴涨与 TIME_WAIT 积压调优",
			Description: "排查高并发下端口耗尽与网络连接状态异常。",
			Severity:    "MEDIUM",
			Steps: []SOPStep{
				{
					StepNumber:  1,
					Title:       "统计当前内核 TCP 各状态连接数",
					Description: "查看 ESTABLISHED、TIME_WAIT、CLOSE_WAIT 数量",
					Command:     "ss -s",
					Explanation: "若 TIME_WAIT 过万或 CLOSE_WAIT 居高不下，需排查连接复用或代码连接泄露",
					IsSafe:      true,
				},
				{
					StepNumber:  2,
					Title:       "分析监听端口与对应服务进程",
					Description: "排查核心对外端口的当前占用情况",
					Command:     "ss -tulpn",
					Explanation: "确认服务监听状态与绑定的进程 PID",
					IsSafe:      true,
				},
			},
		},
	}
}
