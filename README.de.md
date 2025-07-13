# Claude Context

<div align="center">

[English](./README.en.md) | [中文](./README.zh.md) | [日本語](./README.ja.md) | [Español](./README.es.md) | [Français](./README.fr.md) | **Deutsch** | [한국어](./README.md)

</div>

> 🤖 Ein Automatisierungstool, das sicherstellt, dass Claude Code sich immer an Ihren Projektkontext erinnert

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 Schnellstart

### Ein-Klick-Installation

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### Manuelle Installation

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 Hauptfunktionen

### Kernfunktionen
- ✅ **Automatische Kontext-Injektion**: Lädt CLAUDE.md automatisch, wenn Claude Tools verwendet
- ✅ **Schutz vor Gesprächskompression**: Behält Kontext in langen Gesprächen bei (PreCompact Hook, v1.0.48+)
- ✅ **Globale/Projektspezifische Einstellungen**: Flexible Kontextverwaltung
- ✅ **Intelligentes Caching**: Schnelle Leistung (~10ms)

### Erweiterte Funktionen (Optional)
- 🆕 **Gesprächsverlauf-Verwaltung**: Funktioniert unabhängig ohne Gemini
- 🆕 **Automatisches Gesprächs-Tracking**: Automatisches Speichern und Durchsuchen aller Gespräche
- 🆕 **Token-Effizienz-Überwachung**: Intelligente Zusammenfassungen mit Gemini-Integration

## 📋 Anforderungen

- **Claude Code v1.0.48+** (PreCompact Hook-Unterstützung beginnt ab v1.0.48)
  - v1.0.41 ~ v1.0.47: Nur PreToolUse Hook unterstützt (Grundfunktionen funktionieren)
- Bash Shell
- Grundlegende Unix-Tools: `jq`, `sha256sum`, `gzip`
- (Optional) `gemini` CLI - Für Token-Überwachungsfunktionen

## 📖 Verwendung

### 1. CLAUDE.md-Dateien erstellen

**Globale Einstellungen** (`~/.claude/CLAUDE.md`):
```markdown
# Regeln für alle Projekte
- Immer zuerst Tests schreiben
- Klaren und prägnanten Code verwenden
```

**Projektspezifische Einstellungen** (`projekt_wurzel/CLAUDE.md`):
```markdown
# Projektspezifische Regeln
- TypeScript verwenden
- React 18 kompatiblen Code schreiben
```

### 2. Modus konfigurieren

```bash
# Interaktive Konfiguration (empfohlen)
~/.claude/hooks/install/configure_hooks.sh

# Modusauswahl:
# 1) Basic   - Nur CLAUDE.md-Injektion
# 2) History - Gesprächsverlauf-Verwaltung (Gemini nicht erforderlich)
# 3) Advanced - Token-Überwachung (Gemini erforderlich)
```

### 3. Claude Code neu starten

Änderungen werden nach dem Neustart von Claude Code wirksam.

## 🔧 Erweiterte Konfiguration

### Gesprächsverlauf-Verwaltung (Kein Gemini erforderlich)

Alle Gespräche automatisch verfolgen und verwalten:

```bash
# Gesprächsverlauf-Manager
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# Sitzungen auflisten
$MANAGER list

# Gespräche durchsuchen
$MANAGER search "Suchbegriff"

# Sitzung exportieren (markdown/json/txt)
$MANAGER export <session_id> markdown output.md
```

### Token-Überwachung aktivieren (Gemini erforderlich)

Für intelligentere Zusammenfassungen:

1. `gemini` CLI installieren
2. Erweiterte Konfiguration wählen:
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### Umgebungsvariablen

```bash
# Injektionswahrscheinlichkeit anpassen (0.0 ~ 1.0)
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# Cache-Verzeichnis ändern
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ Projektstruktur

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # Einheitlicher Injektor (unterstützt alle Modi)
│   │   └── precompact.sh    # Einheitlicher PreCompact Hook
│   ├── monitor/
│   │   ├── claude_history_manager.sh     # Gesprächsverlauf-Manager
│   │   └── claude_token_monitor_safe.sh  # Token-Monitor
│   └── utils/
│       └── common_functions.sh  # Gemeinsame Funktionsbibliothek
├── install/
│   ├── install.sh           # Installationsskript
│   ├── configure_hooks.sh   # Modus-Konfigurationsskript
│   └── one-line-install.sh  # Ein-Klick-Installation
├── tests/                   # Test-Suite
├── docs/                    # Detaillierte Dokumentation
├── config.sh.template       # Konfigurationsvorlage
└── MIGRATION_GUIDE.md       # Migrationsleitfaden
```

## 🧪 Tests

```bash
# Alle Tests ausführen
./tests/test_all.sh

# Einzelne Komponenten testen
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ Deinstallation

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 Mitwirken

1. Repository forken
2. Feature-Branch erstellen (`git checkout -b feature/amazing`)
3. Änderungen committen (`git commit -m 'Add amazing feature'`)
4. Zum Branch pushen (`git push origin feature/amazing`)
5. Pull Request öffnen

## 📊 Leistung

- Erster Lauf: ~100ms
- Cache-Treffer: ~10ms
- Speichernutzung: < 10MB

## 🔍 Fehlerbehebung

### Wenn Claude CLAUDE.md nicht erkennt
1. Claude Code neu starten
2. Einstellungen überprüfen: `cat ~/.claude/settings.json | jq .hooks`
3. Logs überprüfen: `tail -f /tmp/claude_*.log`

### Wenn die Token-Überwachung nicht funktioniert
1. `gemini`-Installation überprüfen
2. Gesprächsverlauf überprüfen: `ls ~/.claude/history/`
3. Berechtigungen überprüfen: `ls -la ~/.claude/`

## 📝 Lizenz

MIT-Lizenz - Frei verwendbar!

## 🙏 Danksagungen

Dieses Projekt wurde durch die Zusammenarbeit zwischen Claude und Gemini erstellt.