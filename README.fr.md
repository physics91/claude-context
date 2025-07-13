# Claude Context

<div align="center">

[English](./README.en.md) | [中文](./README.zh.md) | [日本語](./README.ja.md) | [Español](./README.es.md) | **Français** | [Deutsch](./README.de.md) | [한국어](./README.md)

</div>

> 🤖 Un outil d'automatisation qui garantit que Claude Code se souvient toujours du contexte de votre projet

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 Démarrage Rapide

### Installation en Un Clic

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### Installation Manuelle

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 Fonctionnalités Principales

### Fonctionnalités de Base
- ✅ **Injection Automatique du Contexte** : Chargement automatique de CLAUDE.md lorsque Claude utilise des outils
- ✅ **Protection de Compression de Conversation** : Maintient le contexte dans les longues conversations (PreCompact hook, v1.0.48+)
- ✅ **Paramètres Globaux/Spécifiques au Projet** : Gestion flexible du contexte
- ✅ **Cache Intelligent** : Performance rapide (~10ms)

### Fonctionnalités Avancées (Optionnel)
- 🆕 **Gestion de l'Historique des Conversations** : Fonctionne indépendamment sans Gemini
- 🆕 **Suivi Automatique des Conversations** : Sauvegarde et recherche automatiques de toutes les conversations
- 🆕 **Surveillance de l'Efficacité des Tokens** : Résumés intelligents avec intégration Gemini

## 📋 Prérequis

- **Claude Code v1.0.48+** (Le support du PreCompact hook commence à partir de v1.0.48)
  - v1.0.41 ~ v1.0.47 : Seul le PreToolUse hook est supporté (les fonctions de base fonctionnent)
- Bash shell
- Outils Unix de base : `jq`, `sha256sum`, `gzip`
- (Optionnel) `gemini` CLI - Pour les fonctionnalités de surveillance des tokens

## 📖 Utilisation

### 1. Créer des Fichiers CLAUDE.md

**Paramètres Globaux** (`~/.claude/CLAUDE.md`) :
```markdown
# Règles pour tous les projets
- Toujours écrire les tests en premier
- Utiliser un code clair et concis
```

**Paramètres Spécifiques au Projet** (`racine_du_projet/CLAUDE.md`) :
```markdown
# Règles spécifiques au projet
- Utiliser TypeScript
- Écrire du code compatible React 18
```

### 2. Configurer le Mode

```bash
# Configuration interactive (recommandée)
~/.claude/hooks/install/configure_hooks.sh

# Sélection du mode :
# 1) Basic   - Injection CLAUDE.md uniquement
# 2) History - Gestion de l'historique des conversations (Gemini non requis)
# 3) Advanced - Surveillance des tokens (Gemini requis)
```

### 3. Redémarrer Claude Code

Les modifications prennent effet après le redémarrage de Claude Code.

## 🔧 Configuration Avancée

### Gestion de l'Historique des Conversations (Sans Gemini)

Suivre et gérer automatiquement toutes les conversations :

```bash
# Gestionnaire d'historique des conversations
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# Lister les sessions
$MANAGER list

# Rechercher dans les conversations
$MANAGER search "mot-clé"

# Exporter une session (markdown/json/txt)
$MANAGER export <session_id> markdown output.md
```

### Activer la Surveillance des Tokens (Gemini Requis)

Pour des résumés plus intelligents :

1. Installer `gemini` CLI
2. Sélectionner la configuration avancée :
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### Variables d'Environnement

```bash
# Ajuster la probabilité d'injection (0.0 ~ 1.0)
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# Changer le répertoire de cache
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ Structure du Projet

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # Injecteur unifié (supporte tous les modes)
│   │   └── precompact.sh    # Hook precompact unifié
│   ├── monitor/
│   │   ├── claude_history_manager.sh     # Gestionnaire d'historique des conversations
│   │   └── claude_token_monitor_safe.sh  # Moniteur de tokens
│   └── utils/
│       └── common_functions.sh  # Bibliothèque de fonctions communes
├── install/
│   ├── install.sh           # Script d'installation
│   ├── configure_hooks.sh   # Script de configuration du mode
│   └── one-line-install.sh  # Installation en un clic
├── tests/                   # Suite de tests
├── docs/                    # Documentation détaillée
├── config.sh.template       # Modèle de configuration
└── MIGRATION_GUIDE.md       # Guide de migration
```

## 🧪 Tests

```bash
# Exécuter tous les tests
./tests/test_all.sh

# Tester des composants individuels
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ Désinstallation

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 Contribuer

1. Forker le dépôt
2. Créer votre branche de fonctionnalité (`git checkout -b feature/amazing`)
3. Commiter vos changements (`git commit -m 'Add amazing feature'`)
4. Pousser vers la branche (`git push origin feature/amazing`)
5. Ouvrir une Pull Request

## 📊 Performance

- Première exécution : ~100ms
- Hit de cache : ~10ms
- Utilisation mémoire : < 10MB

## 🔍 Dépannage

### Quand Claude ne reconnaît pas CLAUDE.md
1. Redémarrer Claude Code
2. Vérifier les paramètres : `cat ~/.claude/settings.json | jq .hooks`
3. Vérifier les logs : `tail -f /tmp/claude_*.log`

### Quand la surveillance des tokens ne fonctionne pas
1. Vérifier l'installation de `gemini`
2. Vérifier l'historique des conversations : `ls ~/.claude/history/`
3. Vérifier les permissions : `ls -la ~/.claude/`

## 📝 Licence

Licence MIT - Utilisez librement !

## 🙏 Remerciements

Ce projet a été créé grâce à la collaboration entre Claude et Gemini.