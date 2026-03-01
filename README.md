# System Monitor Skill

系统健康检查工具。

## 快速开始

```bash
# 完整检查
bash index.sh

# 只看磁盘
bash index.sh --disk

# JSON 输出
bash index.sh --json
```

## 输出示例

```
🖥️ 系统监控 - 2026-03-01 13:00:00

✅ CPU
  - 使用率：25% (8 cores)
  - 负载：1.2, 0.8, 0.5
  - 状态：正常

✅ 内存
  - 已用：8.2GB / 16GB (51%)
  - 状态：正常

📀 磁盘
  - /: 45GB / 100GB (45%) 正常
  - /home: 120GB / 500GB (24%) 正常

📊 总结
  - 状态：ok
  - 警告：0
  - 严重：0
```

## 依赖

- bash
- top
- free
- df
- bc

## 集成示例

### Heartbeat 定期检查

```bash
# 每小时检查并记录
0 * * * * bash ~/.openclaw/workspace/skills/system-monitor/index.sh --json >> /var/log/sysmon.log
```

### 告警

```bash
# 检查状态并发送告警
result=$(bash index.sh --json)
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "warning" ] || [ "$status" = "critical" ]; then
    echo "$result" | curl -X POST https://hook.example.com/alert -d @-
fi
```
