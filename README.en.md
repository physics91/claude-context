# Claude Context

<div align="center">

**English** | [中文](./README.zh.md) | [日本語](./README.ja.md) | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md) | [한국어](./README.md)

</div>

> 🤖 An automation tool that ensures Claude Code always remembers your project context

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 Quick Start

### One-Click Installation

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 Key Features

### Core Features
- ✅ **Automatic Context Injection**: Auto-loads CLAUDE.md when Claude uses tools
- ✅ **Conversation Compression Protection**: Maintains context in long conversations (PreCompact hook, v1.0.48+)
- ✅ **Global/Project-specific Settings**: Flexible context management
- ✅ **Smart Caching**: Fast performance (~10ms)

### Advanced Features (Optional)
- 🆕 **Conversation History Management**: Works independently without Gemini
- 🆕 **Automatic Conversation Tracking**: Auto-save and search all conversations
- 🆕 **Token Efficiency Monitoring**: Intelligent summarization with Gemini integration

## 📋 Requirements

- **Claude Code v1.0.48+** (PreCompact hook support starts from v1.0.48)
  - v1.0.41 ~ v1.0.47: Only PreToolUse hook supported (basic features work)
- Bash shell
- Basic Unix tools: `jq`, `sha256sum`, `gzip`
- (Optional) `gemini` CLI - For token monitoring features

## 📖 Usage

### 1. Create CLAUDE.md Files

**Global Settings** (`~/.claude/CLAUDE.md`):
```markdown
# Rules for all projects
- Always write tests first
- Use clear and concise code
```

**Project-specific Settings** (`project_root/CLAUDE.md`):
```markdown
# Project-specific rules
- Use TypeScript
- Write React 18 compliant code
```

### 2. Configure Mode

```bash
# Interactive configuration (recommended)
~/.claude/hooks/install/configure_hooks.sh

# Mode selection:
# 1) Basic   - CLAUDE.md injection only
# 2) History - Conversation history management (Gemini not required)
# 3) Advanced - Token monitoring (Gemini required)
```

### 3. Restart Claude Code

Changes take effect after restarting Claude Code.

## 🔧 Advanced Configuration

### Conversation History Management (No Gemini Required)

Automatically track and manage all conversations:

```bash
# Conversation history manager
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# List sessions
$MANAGER list

# Search conversations
$MANAGER search "keyword"

# Export session (markdown/json/txt)
$MANAGER export <session_id> markdown output.md
```

### Enable Token Monitoring (Gemini Required)

For more intelligent summarization:

1. Install `gemini` CLI
2. Select advanced configuration:
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### Environment Variables

```bash
# Adjust injection probability (0.0 ~ 1.0)
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# Change cache directory
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ Project Structure

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # Unified injector (supports all modes)
│   │   └── precompact.sh    # Unified precompact hook
│   ├── monitor/
│   │   ├── claude_history_manager.sh     # Conversation history manager
│   │   └── claude_token_monitor_safe.sh  # Token monitor
│   └── utils/
│       └── common_functions.sh  # Common function library
├── install/
│   ├── install.sh           # Installation script
│   ├── configure_hooks.sh   # Mode configuration script
│   └── one-line-install.sh  # One-click install
├── tests/                   # Test suite
├── docs/                    # Detailed documentation
├── config.sh.template       # Configuration template
└── MIGRATION_GUIDE.md       # Migration guide
```

## 🧪 Testing

```bash
# Run all tests
./tests/test_all.sh

# Test individual components
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ Uninstallation

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📊 Performance

- First run: ~100ms
- Cache hit: ~10ms
- Memory usage: < 10MB

## 🔍 Troubleshooting

### When Claude doesn't recognize CLAUDE.md
1. Restart Claude Code
2. Check settings: `cat ~/.claude/settings.json | jq .hooks`
3. Check logs: `tail -f /tmp/claude_*.log`

### When token monitoring doesn't work
1. Verify `gemini` installation
2. Check conversation history: `ls ~/.claude/history/`
3. Check permissions: `ls -la ~/.claude/`

## 📝 License

MIT License - Use freely!

## 🙏 Acknowledgments

This project was created through collaboration between Claude and Gemini.