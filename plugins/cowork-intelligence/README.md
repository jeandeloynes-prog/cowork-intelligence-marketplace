# Cowork Intelligence Framework

Plugin Claude Code / Claude Cowork pour **comprendre, auditer et optimiser** un setup agentique (skills, hooks, MCP, CLAUDE.md, slash commands, orchestration, mémoire, observabilité, gouvernance).

Bilingue : descriptions et triggers en français pour la découvrabilité, contenu technique des skills en anglais pour rester aligné sur la terminologie Anthropic et OpenTelemetry.

---

## Ce que contient le plugin

```
cowork-intelligence-plugin/
├── .claude-plugin/
│   ├── plugin.json                      # Manifest
│   └── marketplace.json                 # Exemple de manifest marketplace
├── skills/
│   ├── cowork-foundations/              # Vocabulaire, hiérarchie d'instructions, lifecycle
│   ├── cowork-skills-hooks-mcp/         # Architecture pratique des extensions
│   ├── cowork-context-token-optimization/ # Prompt caching, context rot, budgets
│   ├── cowork-orchestration-memory/     # Patterns agentiques + memory backends
│   ├── cowork-observability-governance/ # OTel GenAI, plateformes, versioning
│   └── cowork-analysis-engine/          # Audit automatique du setup
│   └── cowork-decision-system/          # Arbres de décision + taxonomie
├── hooks/
│   ├── hooks.json                       # Déclaration des hooks
│   ├── session_start_banner.sh          # Banner discret au démarrage
│   └── token_budget_warner.sh           # Avertissement si contexte stable > seuil
├── commands/
│   ├── cowork-analyze.md                # /cowork-analyze
│   ├── cowork-optimize.md               # /cowork-optimize
│   └── cowork-audit.md                  # /cowork-audit
├── scripts/
│   └── measure_context.sh               # Mesure rapide du contexte stable
├── .mcp.json.example                    # Exemples de serveurs MCP commentés
├── CHANGELOG.md
├── SOURCES.md
└── README.md
```

---

## Pour quoi c'est fait

Tu utilises Claude Code ou Cowork et tu te demandes :
- "Mes skills se déclenchent-elles correctement ?"
- "Combien me coûtent vraiment mes MCP servers en tokens par turn ?"
- "Faut-il que je passe en multi-agent ?"
- "Mon CLAUDE.md est-il trop gros ?"
- "Comment éviter les conflits entre skills ?"
- "Quelle architecture agentique pour mon cas d'usage ?"

Ce plugin répond à ces questions de manière **sourcée et conservatrice** : chaque affirmation est étiquetée `[OFFICIAL]` (source Anthropic primaire) / `[SECONDARY]` (source tierce) / `[UNVERIFIED]` (non vérifié à la rédaction). Quand l'information n'est pas vérifiable, le plugin écrit "I don't know" plutôt que d'inventer.

---

## Installation

### Option A — utilisation locale dans un projet
```
# Depuis la racine de ton projet
mkdir -p .claude/plugins
cp -R /chemin/vers/cowork-intelligence-plugin .claude/plugins/cowork-intelligence
chmod +x .claude/plugins/cowork-intelligence/hooks/*.sh
chmod +x .claude/plugins/cowork-intelligence/scripts/*.sh
```

### Option B — utilisation globale (tous tes projets)
```
mkdir -p ~/.claude/plugins
cp -R /chemin/vers/cowork-intelligence-plugin ~/.claude/plugins/cowork-intelligence
chmod +x ~/.claude/plugins/cowork-intelligence/hooks/*.sh
chmod +x ~/.claude/plugins/cowork-intelligence/scripts/*.sh
```

### Option C — via un marketplace plugin (à vérifier)
Le fichier `.claude-plugin/marketplace.json` donne un exemple de format pour distribuer ce plugin via un repo git. **Le schéma officiel de `marketplace.json` n'a pas été localisé pendant la phase de recherche** — vérifier sur la doc live avant publication.

---

## Utilisation

Une fois le plugin installé :

| Commande | Effet |
|---|---|
| `/cowork-analyze` | Audit complet (skills, hooks, MCP, CLAUDE.md, commands). Rapport priorisé. |
| `/cowork-optimize` | Audit ciblé sur le coût tokens. Plan de réduction. |
| `/cowork-audit` | Audit gouvernance et maintenabilité (versions, schemas, drift). |

Les skills se déclenchent automatiquement quand Claude détecte les triggers (voir la liste dans chaque `SKILL.md`).

Tu peux aussi exécuter le script de mesure hors Claude :
```
bash scripts/measure_context.sh /chemin/vers/ton/projet
```

---

## Hooks installés

| Event | Hook | Action |
|---|---|---|
| `SessionStart` | `session_start_banner.sh` | Imprime une ligne signalant que le plugin est actif |
| `UserPromptSubmit` | `token_budget_warner.sh` | Avertit si le contexte stable mesuré dépasse ~10k tokens |

Les deux hooks sont conçus pour **rester silencieux par défaut** et n'ajouter du contexte qu'en cas de signal réel.

---

## MCP

Le plugin ne déclare AUCUN serveur MCP automatiquement. Le fichier `.mcp.json.example` propose des serveurs courants (filesystem, git) plus un exemple "graphify" **explicitement marqué comme non vérifié**. Copier vers `.mcp.json` et ajuster manuellement.

Rappel : chaque MCP server activé augmente le coût en tokens à chaque turn (descriptions de tools). N'activer que ce que tu utilises.

---

## Désinstallation

Supprimer le dossier `cowork-intelligence` de `.claude/plugins/` (ou `~/.claude/plugins/`). Aucun état n'est persisté ailleurs.

---

## Limites assumées de ce plugin

- **Couverture documentaire partielle.** Anthropic documente les concepts (skills, hooks, MCP, CLAUDE.md) mais certains détails (schéma exact de `marketplace.json`, comportement de `disable-model-invocation`, liste complète des events de hooks supportés) n'étaient pas accessibles via une source primaire pendant la rédaction. Ces gaps sont signalés explicitement dans les skills.
- **Heuristiques de seuils** (skill body > 8 KB = MEDIUM, etc.) sont calibrées sur l'observation de plugins communautaires, pas validées par Anthropic.
- **Estimation tokens à 4 bytes/token** est approximative. Pour des chiffres exacts, utiliser l'endpoint `count_tokens` de l'API Claude.
- **Le plugin ne modifie rien automatiquement.** Toutes les actions correctives sont proposées à l'utilisateur, jamais exécutées.

---

## Licence

MIT. Voir `plugin.json`.

---

## Sources

Voir `SOURCES.md` pour la bibliographie complète (Anthropic engineering blog, docs Claude Code, spec MCP, OpenTelemetry GenAI SemConv, frameworks tiers).
