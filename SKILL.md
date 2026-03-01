---
name: system-monitor
description: "系统健康检查，监控 CPU、内存、磁盘、关键进程。Use when: 系统性能检查、服务器健康监控、故障排查、定期巡检"
metadata:
  {
    "openclaw": {
      "emoji": "🖥️",
      "requires": { "bins": ["bash", "df", "free"] }
    }
  }
---

# System Monitor

系统健康检查工具，监控关键资源使用情况。

## When to Use

✅ **USE this skill when:**

- "检查系统状态"
- "服务器健康监控"
- "系统性能检查"
- "磁盘空间够吗"
- "内存使用率多少"
- "定期巡检"
- "故障排查"

## When NOT to Use

❌ **DON'T use this skill when:**

- 实时监控需求 → 使用 Prometheus/Grafana
- 历史数据分析 → 使用日志分析工具
- 网络监控 → 使用专门的网络工具
- 应用层监控 → 使用 APM 工具

## Commands

### 快速检查

```bash
# 完整检查
system-monitor

# 只看磁盘
system-monitor --disk

# 只看内存
system-monitor --memory

# 只看 CPU
system-monitor --cpu

# 检查特定进程
system-monitor --process nginx
```

### 详细模式

```bash
# 输出详细信息
system-monitor --verbose

# JSON 输出（用于自动化）
system-monitor --json
```

## Output Format

```
🖥️ 系统监控 - 2026-03-01 13:00:00

✅ CPU
  - 使用率：25% (2/8 cores)
  - 负载：1.2, 0.8, 0.5 (1/5/15 min)
  - 状态：正常

✅ 内存
  - 已用：8.2GB / 16GB (51%)
  - 交换：0.5GB / 4GB (12%)
  - 状态：正常

⚠️ 磁盘
  - /: 45GB / 100GB (45%)
  - /home: 120GB / 500GB (24%)
  - 状态：注意（/ 分区超过 80%）

✅ 关键进程
  - nginx: 运行中 (PID 1234)
  - mysql: 运行中 (PID 5678)
  - redis: 未运行

📊 总结
  - 检查项：4
  - 正常：3
  - 警告：1
  - 严重：0
```

## Thresholds

### 警告阈值

| 资源 | 警告 | 严重 |
|------|------|------|
| CPU | > 80% | > 95% |
| 内存 | > 80% | > 95% |
| 磁盘 | > 80% | > 95% |
| 负载 | > CPU 核心数 | > 2x 核心数 |

### 关键进程

默认监控：
- nginx
- mysql / mariadb
- postgresql
- redis
- docker
- sshd

可通过 `--process` 添加自定义进程。

## Quick Responses

**"系统正常吗？"**

```bash
system-monitor
```

**"磁盘空间够吗？"**

```bash
system-monitor --disk
```

**"内存使用情况？"**

```bash
system-monitor --memory
```

**"nginx 在运行吗？"**

```bash
system-monitor --process nginx
```

## Implementation Notes

### 检查项

1. **CPU**: 使用率、负载、核心数
2. **内存**: 已用/总计、交换空间
3. **磁盘**: 各分区使用率
4. **进程**: 关键服务状态

### 命令

```bash
# CPU
top -bn1 | grep "Cpu(s)"
cat /proc/loadavg
nproc

# 内存
free -h
cat /proc/meminfo

# 磁盘
df -h
df -h --total

# 进程
pgrep -x nginx
systemctl status nginx
```

## Notes

- 无需 root 权限（大部分检查）
- 支持 Linux/macOS
- JSON 输出适合自动化集成
- 可集成到 heartbeat 定期检查
- 阈值可自定义

## Examples

### 定期检查

```bash
# Crontab 每小时检查
0 * * * * /path/to/system-monitor --json >> /var/log/sysmon.log
```

### 告警集成

```bash
# 检查并发送告警
if system-monitor --json | jq '.status == "warning"'; then
    curl -X POST "https://hook.example.com/alert" \
        -d "$(system-monitor --json)"
fi
```

### 仪表板数据源

```bash
# 输出 JSON 供仪表板使用
system-monitor --json | jq '.metrics'
```
