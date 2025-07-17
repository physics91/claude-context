# Claude Context

<div align="center">

[English](./README_en.md) | **中文** | [日本語](./README_ja.md) | [한국어](./README.md)

</div>

> 🤖 确保 Claude Code 始终记住项目上下文的自动化工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 要求

- **Claude Code v1.0.48+**（PreCompact hook 支持）
- **操作系统要求：**
  - Linux/macOS: Bash、`jq`、`sha256sum`、`gzip`
  - Windows: PowerShell 5.0+、Git for Windows

## 🚀 安装

### 一键安装

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell):**
```powershell
# 推荐：下载脚本后运行
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

### 手动安装

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 配置

### 1. 创建 CLAUDE.md 文件

**全局设置** (`~/.claude/CLAUDE.md`)：
```markdown
# 所有项目的规则
- 编写清晰简洁的代码
- 始终包含测试
```

**项目特定设置** (`项目根目录/CLAUDE.md`)：
```markdown
# 项目特定规则
- 使用 TypeScript
- React 18 标准
```

### 2. 重启 Claude Code

设置将在重启后自动应用。

## 💡 工作原理

### Hook 系统
利用 Claude Code 的 Hook 系统自动注入上下文：

1. **PreToolUse/UserPromptSubmit Hook**：当 Claude 使用工具或接收提示时注入 CLAUDE.md
2. **PreCompact Hook**：对话被压缩时保护上下文
3. **智能缓存**：对相同文件使用缓存以优化性能（~10ms）

### 优先级
1. 项目特定的 CLAUDE.md（当前工作目录）
2. 全局 CLAUDE.md（~/.claude/）
3. 如果两个文件都存在，将自动合并

## 🎯 高级功能

### 模式选择
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**可用模式：**
- **Basic**：仅 CLAUDE.md 注入（默认）
- **History**：自动对话日志
- **OAuth**：使用 Claude Code 认证的自动摘要 ⭐
- **Advanced**：使用 Gemini CLI 的 Token 监控

### Hook 类型选择
```bash
# 安装时指定 Hook 类型
./install/install.sh --hook-type UserPromptSubmit  # 或 PreToolUse
```

## 🗑️ 卸载

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 故障排除

### Claude 无法识别 CLAUDE.md 时
1. 重启 Claude Code
2. 检查设置：`~/.claude/settings.json` 的 hooks 部分
3. 检查日志：`/tmp/claude_*.log` (Linux/macOS) 或 `%TEMP%\claude_*.log` (Windows)

### 更多文档
- [安装指南](./docs/installation.md)
- [高级配置](./docs/advanced.md)
- [故障排除](./docs/troubleshooting.md)

## 📝 许可证

MIT 许可证