# Claude Context

<div align="center">

[English](./README_en.md) | [中文](./README_zh.md) | [日本語](./README_ja.md) | **Deutsch** | [한국어](./README.md)

</div>

> 🤖 Ein Automatisierungstool, das sicherstellt, dass Claude Code sich immer an Ihren Projektkontext erinnert

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 Anforderungen

- **Claude Code v1.0.48+** (PreCompact Hook-Unterstützung)
- **Betriebssystem-Anforderungen:**
  - Linux/macOS: Bash, `jq`, `sha256sum`, `gzip`
  - Windows: PowerShell 5.0+, Git für Windows

## 🚀 Installation

### Ein-Klick-Installation

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell):**
```powershell
# Empfohlen: Skript herunterladen und dann ausführen
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

### Manuelle Installation

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 Konfiguration

### 1. CLAUDE.md-Dateien erstellen

**Globale Einstellungen** (`~/.claude/CLAUDE.md`):
```markdown
# Regeln für alle Projekte
- Klaren und prägnanten Code schreiben
- Immer Tests einschließen
```

**Projektspezifische Einstellungen** (`projekt_wurzel/CLAUDE.md`):
```markdown
# Projektspezifische Regeln
- TypeScript verwenden
- React 18 Standards
```

### 2. Claude Code neu starten

Die Konfiguration wird nach dem Neustart automatisch angewendet.

## 💡 Funktionsweise

### Hook-System
Nutzt das Hook-System von Claude Code zur automatischen Kontext-Injektion:

1. **PreToolUse/UserPromptSubmit Hook**: Injiziert CLAUDE.md, wenn Claude Tools verwendet oder Prompts empfängt
2. **PreCompact Hook**: Schützt den Kontext, wenn Gespräche komprimiert werden
3. **Intelligentes Caching**: Verwendet Cache für gleiche Dateien zur Leistungsoptimierung (~10ms)

### Priorität
1. Projektspezifische CLAUDE.md (aktuelles Arbeitsverzeichnis)
2. Globale CLAUDE.md (~/.claude/)
3. Beide Dateien werden automatisch zusammengeführt, falls vorhanden

## 🎯 Erweiterte Funktionen

### Modusauswahl
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**Verfügbare Modi:**
- **Basic**: Nur CLAUDE.md-Injektion (Standard)
- **History**: Automatische Gesprächsprotokollierung
- **OAuth**: Automatische Zusammenfassung mit Claude Code-Authentifizierung ⭐
- **Advanced**: Token-Überwachung mit Gemini CLI

### Hook-Typ-Auswahl
```bash
# Hook-Typ bei der Installation angeben
./install/install.sh --hook-type UserPromptSubmit  # oder PreToolUse
```

## 🗑️ Deinstallation

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 Fehlerbehebung

### Wenn Claude CLAUDE.md nicht erkennt
1. Claude Code neu starten
2. Konfiguration prüfen: Hooks-Abschnitt in `~/.claude/settings.json`
3. Logs prüfen: `/tmp/claude_*.log` (Linux/macOS) oder `%TEMP%\claude_*.log` (Windows)

### Weitere Dokumentation
- [Installationsanleitung](./docs/installation.md)
- [Erweiterte Konfiguration](./docs/advanced.md)
- [Fehlerbehebung](./docs/troubleshooting.md)

## 📝 Lizenz

MIT-Lizenz