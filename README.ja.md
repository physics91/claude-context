# Claude Context

<div align="center">

[English](./README.en.md) | [中文](./README.zh.md) | **日本語** | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md) | [한국어](./README.md)

</div>

> 🤖 Claude Code が常にプロジェクトのコンテキストを記憶するための自動化ツール

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 クイックスタート

### ワンクリックインストール

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### 手動インストール

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 主な機能

### コア機能
- ✅ **自動コンテキスト注入**：Claude がツールを使用する際に CLAUDE.md を自動読み込み
- ✅ **会話圧縮保護**：長い会話でもコンテキストを維持（PreCompact hook、v1.0.48+）
- ✅ **グローバル/プロジェクト固有の設定**：柔軟なコンテキスト管理
- ✅ **スマートキャッシング**：高速パフォーマンス（~10ms）

### 高度な機能（オプション）
- 🆕 **会話履歴管理**：Gemini なしで独立して動作
- 🆕 **自動会話追跡**：すべての会話を自動保存・検索
- 🆕 **トークン効率監視**：Gemini 統合による知的な要約

## 📋 要件

- **Claude Code v1.0.48+**（PreCompact hook サポートは v1.0.48 から）
  - v1.0.41 ~ v1.0.47：PreToolUse hook のみサポート（基本機能は動作）
- Bash シェル
- 基本的な Unix ツール：`jq`、`sha256sum`、`gzip`
- （オプション）`gemini` CLI - トークン監視機能用

## 📖 使い方

### 1. CLAUDE.md ファイルの作成

**グローバル設定** (`~/.claude/CLAUDE.md`)：
```markdown
# すべてのプロジェクトのルール
- 常にテストを先に書く
- 明確で簡潔なコードを使用する
```

**プロジェクト固有の設定** (`プロジェクトルート/CLAUDE.md`)：
```markdown
# プロジェクト固有のルール
- TypeScript を使用
- React 18 準拠のコードを書く
```

### 2. モードの設定

```bash
# インタラクティブ設定（推奨）
~/.claude/hooks/install/configure_hooks.sh

# モード選択：
# 1) Basic   - CLAUDE.md 注入のみ
# 2) History - 会話履歴管理（Gemini 不要）
# 3) Advanced - トークン監視（Gemini 必要）
```

### 3. Claude Code の再起動

Claude Code を再起動すると変更が反映されます。

## 🔧 高度な設定

### 会話履歴管理（Gemini 不要）

すべての会話を自動的に追跡・管理：

```bash
# 会話履歴マネージャー
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# セッション一覧
$MANAGER list

# 会話検索
$MANAGER search "キーワード"

# セッションのエクスポート（markdown/json/txt）
$MANAGER export <session_id> markdown output.md
```

### トークン監視を有効化（Gemini 必要）

より知的な要約のために：

1. `gemini` CLI をインストール
2. 高度な設定を選択：
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### 環境変数

```bash
# 注入確率の調整（0.0 ~ 1.0）
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# キャッシュディレクトリの変更
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ プロジェクト構造

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # 統合インジェクター（全モード対応）
│   │   └── precompact.sh    # 統合 precompact hook
│   ├── monitor/
│   │   ├── claude_history_manager.sh     # 会話履歴マネージャー
│   │   └── claude_token_monitor_safe.sh  # トークンモニター
│   └── utils/
│       └── common_functions.sh  # 共通関数ライブラリ
├── install/
│   ├── install.sh           # インストールスクリプト
│   ├── configure_hooks.sh   # モード設定スクリプト
│   └── one-line-install.sh  # ワンクリックインストール
├── tests/                   # テストスイート
├── docs/                    # 詳細なドキュメント
├── config.sh.template       # 設定テンプレート
└── MIGRATION_GUIDE.md       # 移行ガイド
```

## 🧪 テスト

```bash
# すべてのテストを実行
./tests/test_all.sh

# 個別コンポーネントのテスト
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ アンインストール

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 貢献

1. リポジトリをフォーク
2. 機能ブランチを作成（`git checkout -b feature/amazing`）
3. 変更をコミット（`git commit -m 'Add amazing feature'`）
4. ブランチにプッシュ（`git push origin feature/amazing`）
5. Pull Request を開く

## 📊 パフォーマンス

- 初回実行：~100ms
- キャッシュヒット：~10ms
- メモリ使用量：< 10MB

## 🔍 トラブルシューティング

### Claude が CLAUDE.md を認識しない場合
1. Claude Code を再起動
2. 設定を確認：`cat ~/.claude/settings.json | jq .hooks`
3. ログを確認：`tail -f /tmp/claude_*.log`

### トークン監視が動作しない場合
1. `gemini` のインストールを確認
2. 会話履歴を確認：`ls ~/.claude/history/`
3. 権限を確認：`ls -la ~/.claude/`

## 📝 ライセンス

MIT ライセンス - 自由にご利用ください！

## 🙏 謝辞

このプロジェクトは Claude と Gemini の協力により作成されました。