# Claude Context

<div align="center">

**English** | [中文](./README_zh.md) | [日本語](./README_ja.md) | [한국어](./README.md)

</div>

> 🤖 An automation tool that ensures Claude Code always remembers your project context

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 Requirements

- **Claude Code v1.0.48+** (PreCompact hook support)
- **OS Requirements:**
  - Linux/macOS: Bash, `jq`, `sha256sum`, `gzip`
  - Windows: PowerShell 5.0+, Git for Windows

## 🚀 Installation

### One-Click Installation

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell):**
```powershell
# Recommended: Download script then run
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

### Manual Installation

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 Configuration

### 1. Create CLAUDE.md Files

**Global Settings** (`~/.claude/CLAUDE.md`):
```markdown
# Rules for all projects
- Write clear and concise code
- Always include tests
```

**Project-specific Settings** (`project_root/CLAUDE.md`):
```markdown
# Project-specific rules
- Use TypeScript
- React 18 standards
```

### 2. Restart Claude Code

Settings are automatically applied after restart.

## 💡 How It Works

### Hook System
Leverages Claude Code's Hook system to automatically inject context:

1. **PreToolUse/UserPromptSubmit Hook**: Injects CLAUDE.md when Claude uses tools or receives prompts
2. **PreCompact Hook**: Protects context when conversations get compressed
3. **Smart Caching**: Uses cache for same files to optimize performance (~10ms)

### Priority
1. Project-specific CLAUDE.md (current working directory)
2. Global CLAUDE.md (~/.claude/)
3. Both files are automatically merged if present

## 🎯 Advanced Features

### Mode Selection
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**Available Modes:**
- **Basic**: CLAUDE.md injection only (default)
- **History**: Automatic conversation logging
- **OAuth**: Automatic summarization using Claude Code auth ⭐
- **Advanced**: Token monitoring with Gemini CLI

### Hook Type Selection
```bash
# Specify hook type during installation
./install/install.sh --hook-type UserPromptSubmit  # or PreToolUse
```

## 🗑️ Uninstallation

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 Troubleshooting

### When Claude doesn't recognize CLAUDE.md
1. Restart Claude Code
2. Check settings: `~/.claude/settings.json` hooks section
3. Check logs: `/tmp/claude_*.log` (Linux/macOS) or `%TEMP%\claude_*.log` (Windows)

### More Documentation
- [Installation Guide](./docs/installation.md)
- [Advanced Configuration](./docs/advanced.md)
- [Troubleshooting](./docs/troubleshooting.md)

## 📝 License

MIT License