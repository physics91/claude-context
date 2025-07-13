# Claude Context

<div align="center">

[English](./README.en.md) | [中文](./README.zh.md) | [日本語](./README.ja.md) | **Español** | [Français](./README.fr.md) | [Deutsch](./README.de.md) | [한국어](./README.md)

</div>

> 🤖 Una herramienta de automatización que asegura que Claude Code siempre recuerde el contexto de tu proyecto

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 Inicio Rápido

### Instalación con un Clic

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### Instalación Manual

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 Características Principales

### Características Principales
- ✅ **Inyección Automática de Contexto**: Carga automática de CLAUDE.md cuando Claude usa herramientas
- ✅ **Protección de Compresión de Conversación**: Mantiene el contexto en conversaciones largas (PreCompact hook, v1.0.48+)
- ✅ **Configuración Global/Específica del Proyecto**: Gestión flexible del contexto
- ✅ **Caché Inteligente**: Rendimiento rápido (~10ms)

### Características Avanzadas (Opcional)
- 🆕 **Gestión del Historial de Conversaciones**: Funciona independientemente sin Gemini
- 🆕 **Seguimiento Automático de Conversaciones**: Guardar y buscar automáticamente todas las conversaciones
- 🆕 **Monitoreo de Eficiencia de Tokens**: Resúmenes inteligentes con integración de Gemini

## 📋 Requisitos

- **Claude Code v1.0.48+** (El soporte de PreCompact hook comienza desde v1.0.48)
  - v1.0.41 ~ v1.0.47: Solo se admite PreToolUse hook (las funciones básicas funcionan)
- Bash shell
- Herramientas Unix básicas: `jq`, `sha256sum`, `gzip`
- (Opcional) `gemini` CLI - Para funciones de monitoreo de tokens

## 📖 Uso

### 1. Crear Archivos CLAUDE.md

**Configuración Global** (`~/.claude/CLAUDE.md`):
```markdown
# Reglas para todos los proyectos
- Siempre escribir pruebas primero
- Usar código claro y conciso
```

**Configuración Específica del Proyecto** (`raíz_del_proyecto/CLAUDE.md`):
```markdown
# Reglas específicas del proyecto
- Usar TypeScript
- Escribir código compatible con React 18
```

### 2. Configurar Modo

```bash
# Configuración interactiva (recomendada)
~/.claude/hooks/install/configure_hooks.sh

# Selección de modo:
# 1) Basic   - Solo inyección de CLAUDE.md
# 2) History - Gestión del historial de conversaciones (no requiere Gemini)
# 3) Advanced - Monitoreo de tokens (requiere Gemini)
```

### 3. Reiniciar Claude Code

Los cambios se aplican después de reiniciar Claude Code.

## 🔧 Configuración Avanzada

### Gestión del Historial de Conversaciones (No Requiere Gemini)

Rastrea y gestiona automáticamente todas las conversaciones:

```bash
# Gestor del historial de conversaciones
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# Listar sesiones
$MANAGER list

# Buscar conversaciones
$MANAGER search "palabra clave"

# Exportar sesión (markdown/json/txt)
$MANAGER export <session_id> markdown output.md
```

### Habilitar Monitoreo de Tokens (Requiere Gemini)

Para resúmenes más inteligentes:

1. Instalar `gemini` CLI
2. Seleccionar configuración avanzada:
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### Variables de Entorno

```bash
# Ajustar probabilidad de inyección (0.0 ~ 1.0)
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# Cambiar directorio de caché
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ Estructura del Proyecto

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # Inyector unificado (soporta todos los modos)
│   │   └── precompact.sh    # Hook precompact unificado
│   ├── monitor/
│   │   ├── claude_history_manager.sh     # Gestor del historial de conversaciones
│   │   └── claude_token_monitor_safe.sh  # Monitor de tokens
│   └── utils/
│       └── common_functions.sh  # Biblioteca de funciones comunes
├── install/
│   ├── install.sh           # Script de instalación
│   ├── configure_hooks.sh   # Script de configuración de modo
│   └── one-line-install.sh  # Instalación con un clic
├── tests/                   # Suite de pruebas
├── docs/                    # Documentación detallada
├── config.sh.template       # Plantilla de configuración
└── MIGRATION_GUIDE.md       # Guía de migración
```

## 🧪 Pruebas

```bash
# Ejecutar todas las pruebas
./tests/test_all.sh

# Probar componentes individuales
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ Desinstalación

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 Contribuir

1. Hacer fork del repositorio
2. Crear tu rama de características (`git checkout -b feature/amazing`)
3. Hacer commit de tus cambios (`git commit -m 'Add amazing feature'`)
4. Hacer push a la rama (`git push origin feature/amazing`)
5. Abrir un Pull Request

## 📊 Rendimiento

- Primera ejecución: ~100ms
- Hit de caché: ~10ms
- Uso de memoria: < 10MB

## 🔍 Solución de Problemas

### Cuando Claude no reconoce CLAUDE.md
1. Reiniciar Claude Code
2. Verificar configuración: `cat ~/.claude/settings.json | jq .hooks`
3. Verificar logs: `tail -f /tmp/claude_*.log`

### Cuando el monitoreo de tokens no funciona
1. Verificar instalación de `gemini`
2. Verificar historial de conversaciones: `ls ~/.claude/history/`
3. Verificar permisos: `ls -la ~/.claude/`

## 📝 Licencia

Licencia MIT - ¡Úsalo libremente!

## 🙏 Agradecimientos

Este proyecto fue creado a través de la colaboración entre Claude y Gemini.