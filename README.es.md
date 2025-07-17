# Claude Context

<div align="center">

[English](./README_en.md) | [中文](./README_zh.md) | [日本語](./README_ja.md) | **Español** | [한국어](./README.md)

</div>

> 🤖 Una herramienta de automatización que asegura que Claude Code siempre recuerde el contexto de tu proyecto

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 Requisitos

- **Claude Code v1.0.48+** (Soporte de PreCompact hook)
- **Requisitos por SO:**
  - Linux/macOS: Bash, `jq`, `sha256sum`, `gzip`
  - Windows: PowerShell 5.0+, Git para Windows

## 🚀 Instalación

### Instalación con un Clic

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell):**
```powershell
# Recomendado: Descargar script y luego ejecutar
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

### Instalación Manual

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 Configuración

### 1. Crear Archivos CLAUDE.md

**Configuración Global** (`~/.claude/CLAUDE.md`):
```markdown
# Reglas para todos los proyectos
- Escribir código claro y conciso
- Siempre incluir pruebas
```

**Configuración Específica del Proyecto** (`raíz_del_proyecto/CLAUDE.md`):
```markdown
# Reglas específicas del proyecto
- Usar TypeScript
- Estándares de React 18
```

### 2. Reiniciar Claude Code

La configuración se aplica automáticamente después del reinicio.

## 💡 Cómo Funciona

### Sistema de Hooks
Aprovecha el sistema de Hooks de Claude Code para inyectar automáticamente el contexto:

1. **Hook PreToolUse/UserPromptSubmit**: Inyecta CLAUDE.md cuando Claude usa herramientas o recibe prompts
2. **Hook PreCompact**: Protege el contexto cuando las conversaciones se comprimen
3. **Caché Inteligente**: Usa caché para archivos iguales optimizando el rendimiento (~10ms)

### Prioridad
1. CLAUDE.md específico del proyecto (directorio de trabajo actual)
2. CLAUDE.md global (~/.claude/)
3. Ambos archivos se fusionan automáticamente si existen

## 🎯 Funciones Avanzadas

### Selección de Modo
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**Modos Disponibles:**
- **Basic**: Solo inyección de CLAUDE.md (predeterminado)
- **History**: Registro automático de conversaciones
- **OAuth**: Resumen automático usando autenticación de Claude Code ⭐
- **Advanced**: Monitoreo de tokens con Gemini CLI

### Selección de Tipo de Hook
```bash
# Especificar tipo de hook durante la instalación
./install/install.sh --hook-type UserPromptSubmit  # o PreToolUse
```

## 🗑️ Desinstalación

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 Solución de Problemas

### Cuando Claude no reconoce CLAUDE.md
1. Reiniciar Claude Code
2. Verificar configuración: sección hooks de `~/.claude/settings.json`
3. Verificar logs: `/tmp/claude_*.log` (Linux/macOS) o `%TEMP%\claude_*.log` (Windows)

### Más Documentación
- [Guía de Instalación](./docs/installation.md)
- [Configuración Avanzada](./docs/advanced.md)
- [Solución de Problemas](./docs/troubleshooting.md)

## 📝 Licencia

Licencia MIT