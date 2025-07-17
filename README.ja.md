# Claude Context

<div align="center">

[English](./README_en.md) | [中文](./README_zh.md) | **日本語** | [한국어](./README.md)

</div>

> 🤖 Claude Code が常にプロジェクトのコンテキストを記憶するための自動化ツール

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 要件

- **Claude Code v1.0.48+**（PreCompact hook サポート）
- **OS別要件：**
  - Linux/macOS: Bash、`jq`、`sha256sum`、`gzip`
  - Windows: PowerShell 5.0+、Git for Windows

## 🚀 インストール

### ワンクリックインストール

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell):**
```powershell
# 推奨: スクリプトをダウンロードしてから実行
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

### 手動インストール

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 設定

### 1. CLAUDE.md ファイルの作成

**グローバル設定** (`~/.claude/CLAUDE.md`)：
```markdown
# すべてのプロジェクトのルール
- 明確で簡潔なコードを書く
- 常にテストを含める
```

**プロジェクト固有の設定** (`プロジェクトルート/CLAUDE.md`)：
```markdown
# プロジェクト固有のルール
- TypeScript を使用
- React 18 基準
```

### 2. Claude Code の再起動

設定は再起動後に自動的に適用されます。

## 💡 動作原理

### Hook システム
Claude Code の Hook システムを活用して自動的にコンテキストを注入：

1. **PreToolUse/UserPromptSubmit Hook**：Claude がツールを使用するかプロンプトを受け取るときに CLAUDE.md を注入
2. **PreCompact Hook**：会話が圧縮されるときにコンテキストを保護
3. **スマートキャッシング**：同じファイルにはキャッシュを使用してパフォーマンスを最適化（~10ms）

### 優先順位
1. プロジェクト固有の CLAUDE.md（現在の作業ディレクトリ）
2. グローバル CLAUDE.md（~/.claude/）
3. 両方のファイルが存在する場合は自動的にマージ

## 🎯 高度な機能

### モード選択
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**利用可能なモード：**
- **Basic**：CLAUDE.md 注入のみ（デフォルト）
- **History**：自動会話ログ
- **OAuth**：Claude Code 認証を使用した自動要約 ⭐
- **Advanced**：Gemini CLI でトークン監視

### Hook タイプ選択
```bash
# インストール時に Hook タイプを指定
./install/install.sh --hook-type UserPromptSubmit  # または PreToolUse
```

## 🗑️ アンインストール

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 トラブルシューティング

### Claude が CLAUDE.md を認識しない場合
1. Claude Code を再起動
2. 設定を確認：`~/.claude/settings.json` の hooks セクション
3. ログを確認：`/tmp/claude_*.log` (Linux/macOS) または `%TEMP%\claude_*.log` (Windows)

### 詳細なドキュメント
- [インストールガイド](./docs/installation.md)
- [高度な設定](./docs/advanced.md)
- [トラブルシューティング](./docs/troubleshooting.md)

## 📝 ライセンス

MIT ライセンス