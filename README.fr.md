# Claude Context

<div align="center">

[English](./README_en.md) | [中文](./README_zh.md) | [日本語](./README_ja.md) | **Français** | [한국어](./README.md)

</div>

> 🤖 Un outil d'automatisation qui garantit que Claude Code se souvient toujours du contexte de votre projet

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 Prérequis

- **Claude Code v1.0.48+** (Support du PreCompact hook)
- **Prérequis par OS :**
  - Linux/macOS : Bash, `jq`, `sha256sum`, `gzip`
  - Windows : PowerShell 5.0+, Git pour Windows

## 🚀 Installation

### Installation en Un Clic

**Linux/macOS :**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell) :**
```powershell
# Recommandé : Télécharger le script puis l'exécuter
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

### Installation Manuelle

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 Configuration

### 1. Créer des Fichiers CLAUDE.md

**Paramètres Globaux** (`~/.claude/CLAUDE.md`) :
```markdown
# Règles pour tous les projets
- Écrire du code clair et concis
- Toujours inclure des tests
```

**Paramètres Spécifiques au Projet** (`racine_du_projet/CLAUDE.md`) :
```markdown
# Règles spécifiques au projet
- Utiliser TypeScript
- Standards React 18
```

### 2. Redémarrer Claude Code

La configuration s'applique automatiquement après le redémarrage.

## 💡 Comment ça Fonctionne

### Système de Hooks
Exploite le système de Hooks de Claude Code pour injecter automatiquement le contexte :

1. **Hook PreToolUse/UserPromptSubmit** : Injecte CLAUDE.md quand Claude utilise des outils ou reçoit des prompts
2. **Hook PreCompact** : Protège le contexte quand les conversations sont compressées
3. **Cache Intelligent** : Utilise le cache pour les mêmes fichiers afin d'optimiser les performances (~10ms)

### Priorité
1. CLAUDE.md spécifique au projet (répertoire de travail actuel)
2. CLAUDE.md global (~/.claude/)
3. Les deux fichiers sont automatiquement fusionnés s'ils existent

## 🎯 Fonctionnalités Avancées

### Sélection du Mode
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**Modes Disponibles :**
- **Basic** : Injection CLAUDE.md uniquement (par défaut)
- **History** : Journalisation automatique des conversations
- **OAuth** : Résumé automatique utilisant l'authentification Claude Code ⭐
- **Advanced** : Surveillance des tokens avec Gemini CLI

### Sélection du Type de Hook
```bash
# Spécifier le type de hook pendant l'installation
./install/install.sh --hook-type UserPromptSubmit  # ou PreToolUse
```

## 🗑️ Désinstallation

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 Dépannage

### Quand Claude ne reconnaît pas CLAUDE.md
1. Redémarrer Claude Code
2. Vérifier la configuration : section hooks de `~/.claude/settings.json`
3. Vérifier les logs : `/tmp/claude_*.log` (Linux/macOS) ou `%TEMP%\claude_*.log` (Windows)

### Plus de Documentation
- [Guide d'Installation](./docs/installation.md)
- [Configuration Avancée](./docs/advanced.md)
- [Dépannage](./docs/troubleshooting.md)

## 📝 Licence

Licence MIT