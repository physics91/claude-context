# Claude Context

<div align="center">

[English](./README.en.md) | **中文** | [日本語](./README.ja.md) | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md) | [한국어](./README.md)

</div>

> 🤖 确保 Claude Code 始终记住项目上下文的自动化工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 快速开始

### 一键安装

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### 手动安装

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 主要功能

### 核心功能
- ✅ **自动上下文注入**：Claude 使用工具时自动加载 CLAUDE.md
- ✅ **对话压缩保护**：在长对话中保持上下文（PreCompact hook，v1.0.48+）
- ✅ **全局/项目特定设置**：灵活的上下文管理
- ✅ **智能缓存**：快速性能（~10ms）

### 高级功能（可选）
- 🆕 **对话历史管理**：无需 Gemini 即可独立运行
- 🆕 **自动对话跟踪**：自动保存和搜索所有对话
- 🆕 **Token 效率监控**：与 Gemini 集成的智能摘要

## 📋 要求

- **Claude Code v1.0.48+**（PreCompact hook 支持从 v1.0.48 开始）
  - v1.0.41 ~ v1.0.47：仅支持 PreToolUse hook（基本功能可用）
- Bash shell
- 基本 Unix 工具：`jq`、`sha256sum`、`gzip`
- （可选）`gemini` CLI - 用于 token 监控功能

## 📖 使用方法

### 1. 创建 CLAUDE.md 文件

**全局设置** (`~/.claude/CLAUDE.md`)：
```markdown
# 所有项目的规则
- 始终先编写测试
- 使用清晰简洁的代码
```

**项目特定设置** (`项目根目录/CLAUDE.md`)：
```markdown
# 项目特定规则
- 使用 TypeScript
- 编写符合 React 18 的代码
```

### 2. 配置模式

```bash
# 交互式配置（推荐）
~/.claude/hooks/install/configure_hooks.sh

# 模式选择：
# 1) Basic   - 仅 CLAUDE.md 注入
# 2) History - 对话历史管理（不需要 Gemini）
# 3) Advanced - Token 监控（需要 Gemini）
```

### 3. 重启 Claude Code

重启 Claude Code 后更改生效。

## 🔧 高级配置

### 对话历史管理（无需 Gemini）

自动跟踪和管理所有对话：

```bash
# 对话历史管理器
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# 列出会话
$MANAGER list

# 搜索对话
$MANAGER search "关键词"

# 导出会话（markdown/json/txt）
$MANAGER export <session_id> markdown output.md
```

### 启用 Token 监控（需要 Gemini）

获得更智能的摘要：

1. 安装 `gemini` CLI
2. 选择高级配置：
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### 环境变量

```bash
# 调整注入概率（0.0 ~ 1.0）
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# 更改缓存目录
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ 项目结构

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # 统一注入器（支持所有模式）
│   │   └── precompact.sh    # 统一 precompact hook
│   ├── monitor/
│   │   ├── claude_history_manager.sh     # 对话历史管理器
│   │   └── claude_token_monitor_safe.sh  # Token 监控器
│   └── utils/
│       └── common_functions.sh  # 公共函数库
├── install/
│   ├── install.sh           # 安装脚本
│   ├── configure_hooks.sh   # 模式配置脚本
│   └── one-line-install.sh  # 一键安装
├── tests/                   # 测试套件
├── docs/                    # 详细文档
├── config.sh.template       # 配置模板
└── MIGRATION_GUIDE.md       # 迁移指南
```

## 🧪 测试

```bash
# 运行所有测试
./tests/test_all.sh

# 测试单个组件
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ 卸载

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 贡献

1. Fork 仓库
2. 创建功能分支（`git checkout -b feature/amazing`）
3. 提交更改（`git commit -m 'Add amazing feature'`）
4. 推送到分支（`git push origin feature/amazing`）
5. 开启 Pull Request

## 📊 性能

- 首次运行：~100ms
- 缓存命中：~10ms
- 内存使用：< 10MB

## 🔍 故障排除

### Claude 无法识别 CLAUDE.md 时
1. 重启 Claude Code
2. 检查设置：`cat ~/.claude/settings.json | jq .hooks`
3. 检查日志：`tail -f /tmp/claude_*.log`

### Token 监控不工作时
1. 验证 `gemini` 安装
2. 检查对话历史：`ls ~/.claude/history/`
3. 检查权限：`ls -la ~/.claude/`

## 📝 许可证

MIT 许可证 - 自由使用！

## 🙏 致谢

本项目由 Claude 和 Gemini 协作创建。