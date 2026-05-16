# Changelog

Toutes les évolutions notables du plugin `cowork-intelligence` sont consignées ici.

Format : [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning : [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.3.0] — 2026-05-16

### Added — Graphify integration
- **Skill `cowork-graphify`** : intégration du knowledge graph Graphify Erudiam (16K nodes, 127K edges sur concours-eu observés en live via MCP). Documente le pattern pre-dev (consultation) / post-dev (re-indexation), les 7 tools du MCP `graphify-erudiam`, le format de `~/.claude/graphify-config.json`, le support multi-scope (`user` transverse + `<project>` par repo).
- **Slash command `/cowork-intelligence:cowork-graphify-query <question>`** : wrapper convivial autour de `mcp__graphify-erudiam__query_graph`. Parse `depth` et `budget` optionnels.
- **Slash command `/cowork-intelligence:cowork-graphify-refresh [scope]`** : invoque `scripts/graphify_refresh.sh` pour re-indexer un scope (`user`, `<project>`, `all`).
- **Script `scripts/graphify_refresh.sh`** : lit `~/.claude/graphify-config.json`, applique un debounce (30s par défaut), exécute le CLI Graphify configuré. Stamp dans `~/.claude/data/graphify-stamps/<scope>`.
- **Hook `PostToolUse` matcher `Edit|Write|MultiEdit`** (`graphify_post_edit.sh`) : déclenche la re-indexation en arrière-plan après toute modification de fichier. Silent si `graphify-config.json` absent (opt-in).

### Notes
- **Configuration requise côté utilisateur** : créer `~/.claude/graphify-config.json` avec le chemin binaire (`/Users/admin/.local/bin/graphify` détecté) et les `command_args` adaptés à la signature du CLI (à découvrir via `graphify --help`).
- **Graceful degradation** : sans fichier de config, aucun nouveau composant ne s'exécute. Les anciennes features de la v0.2.3 restent disponibles.
- **Limites assumées** :
  - Le support multi-graph d'une seule instance Graphify n'a pas été vérifié — si Graphify est mono-graphe, il faudra deux instances (deux entrées dans `.mcp.json`).
  - L'invalidation du cache MCP après re-indexation n'est pas garantie.
  - Le hook PostToolUse fire-and-forget : si le rebuild échoue, le log est dans `~/.claude/data/graphify-stamps/post-edit.log`, pas remonté au user.

---

## [0.2.3] — 2026-05-16

### Changed
- Descriptions de 3 skills et 3 commands réécrites pour réduire la collision de triggers sur le mot « audit » (finding HIGH de l'audit `cowork-analyze` exécuté en interne) :
  - `cowork-analysis-engine` : ouvre désormais par « Static analyzer pour un setup… » au lieu de « Audit automatique… ». Plus discriminant pour le matcher.
  - `cowork-mcp-audit` : ouvre par « Inventaire et chiffrage des MCP servers… » au lieu de « Audit dédié aux MCP servers… ». Mentionne explicitement le helper `probe_mcp_server.sh`.
  - `cowork-observability-governance` : précise que la skill couvre instrumentation/tracing/gouvernance, **pas** l'analyse statique (cross-ref vers `cowork-analysis-engine`). Trigger « audit AI » retiré.
  - `/cowork-analyze` : « Scan complet » au lieu de « Audit complet ».
  - `/cowork-audit` : « Revue gouvernance » au lieu de « Audit gouvernance ».
  - `/cowork-optimize` : « Plan de réduction » au lieu de « Audit ciblé ».
- Aucun rename. Aucune signature publique modifiée. Les 6 commandes/skills se déclenchent par les mêmes phrases utilisateur qu'avant — seul le mot d'ouverture varie pour aider le matcher à choisir entre les 6 entités.

### Notes
- Option B retenue (durcissement descriptions), Option A (rename) rejetée car breaking change non justifié.
- Findings upstream non adressés ici : timeouts manquants sur hooks vercel/superpowers, 5 SKILL.md > 20 KB, description superpowers `test-driven-development` < 80 chars, 9 descriptions superpowers en « Use when… ». Templates de PR à filer fournis séparément.

---

## [0.2.2] — 2026-05-16 — hotfix

### Fixed
- **`.claude-plugin/plugin.json`** : retrait des blocs `commands`, `skills` et `hooks` ajoutés à tort en v0.2.1. Ils étaient documentés dans des recherches non-primaires comme « champs optionnels » mais sont en réalité **rejetés par le validateur de manifest de Claude Code 2.1.118** (`Validation errors: hooks: Invalid input, commands: Invalid input, skills: Invalid input` via `/doctor`). Le plugin v0.2.1 ne se chargeait pas du tout pour cette raison.
- Confirmé empiriquement : Claude Code découvre automatiquement les sous-dossiers `commands/`, `skills/` et `hooks/hooks.json` sans déclaration explicite. La déclaration explicite n'est pas seulement inutile, elle casse le manifest.

### Known limitation
- Sur Claude Code 2.1.118, les slash commands de plugin restent invocables **uniquement avec le namespace** : `/cowork-intelligence:cowork-analyze`. Le retrait des fausses déclarations ne change pas ce comportement.

---

## [0.2.1] — 2026-05-16 — broken release, do not use

### Fixed
- `hooks/token_budget_warner.sh` : ne somme plus les **bodies** des SKILL.md (cause de sur-estimation massive en v0.2.0). Compte désormais : (a) le contenu complet de la cascade CLAUDE.md, (b) le seul champ `description` du frontmatter YAML de chaque SKILL.md. Estimation per-turn correcte.
- `hooks/legal_keyword_suggester.sh` : remplace les forks `python3` par `jq` pour le parsing de `settings.json`. Hook plus rapide à chaque prompt. Fallback silencieux si `jq` absent.
- `commands/cowork-legal-mode.md` : note explicite — `/reload-plugins` ne désactive pas réellement un plugin déjà chargé dans la session ; il faut **redémarrer Claude Code** pour que `off` prenne plein effet.
- `README.md` : avertissement sur le namespace requis pour les slash commands sur Claude Code 2.x (`/cowork-intelligence:<command>`).

### Added
- `hooks/hooks.json` : champs `"timeout"` (5000 ms pour banner et token_warner, 3000 ms pour le legal suggester) pour borner le coût des hooks.
- `.claude-plugin/plugin.json` : déclarations explicites `commands`, `skills`, `hooks`. Tente d'activer la découverte non-namespacée des slash commands (à valider sur Claude Code 2.x).

---

## [0.2.0] — 2026-05-16

### Added
- New skill `cowork-mcp-audit` : dedicated MCP server audit with conservative cost estimation and live-probe helper.
- New slash command `/cowork-legal-mode <on|off>` : batch enable/disable the 13 `claude-for-legal` plugins via safe JSON patch (jq) with timestamped backup.
- New script `scripts/toggle_legal_plugins.sh` : underlying mechanism for the slash command above. Backup → jq patch → validate → atomic mv.
- New script `scripts/detect_weak_descriptions.sh` : robust SKILL.md description scanner that correctly handles YAML multiline scalars (`|`, `>`). Replaces the v0.1.0 awk heuristic which produced false positives.
- New script `scripts/probe_mcp_server.sh` : stdio JSON-RPC probe to measure the real per-turn cost of a given MCP server (tool count, description bytes, schema bytes, total tokens).
- New `UserPromptSubmit` hook `hooks/legal_keyword_suggester.sh` : silently suggests `/cowork-legal-mode on` when a legal keyword is detected in the user prompt AND fewer than 3 legal plugins are enabled. Silent otherwise.

### Changed
- `scripts/measure_context.sh` : full rewrite. Deduplicates paths via `realpath` (no more double-counting when run from `$HOME`), scans `~/.claude/skills/` (was missing in v0.1.0), and prints per-section subtotals.
- `.claude-plugin/plugin.json` : version 0.1.0 → 0.2.0, author is now an object, homepage and repository filled in.

### Notes
- v0.2.0 explicitly addresses three audit findings reported on v0.1.0 in the field :
  1. User-level skills outside the plugin cache were missed by the measurement script.
  2. Description detection produced false positives ("1 char") on YAML multiline.
  3. No tooling to measure the real MCP cost — added via `cowork-mcp-audit` skill + `probe_mcp_server.sh`.

---

## [0.1.0] — 2026-05-16

### Added
- Manifest `.claude-plugin/plugin.json` (name, version, description, author, license, keywords).
- Manifest `.claude-plugin/marketplace.json` (exemple — schéma officiel non vérifié).
- 6 skills consolidés :
  - `cowork-foundations`
  - `cowork-skills-hooks-mcp`
  - `cowork-context-token-optimization`
  - `cowork-orchestration-memory`
  - `cowork-observability-governance`
  - `cowork-analysis-engine`
  - `cowork-decision-system`
- 2 hooks :
  - `SessionStart` → `session_start_banner.sh` (1 ligne discrète).
  - `UserPromptSubmit` → `token_budget_warner.sh` (silencieux sauf si seuil dépassé).
- 3 slash commands :
  - `/cowork-analyze` (audit complet)
  - `/cowork-optimize` (audit tokens uniquement)
  - `/cowork-audit` (gouvernance / maintenabilité)
- Script utilitaire `scripts/measure_context.sh` pour mesure hors-ligne.
- Fichier `.mcp.json.example` (filesystem, git, exemple graphify non vérifié).
- `README.md` et `SOURCES.md`.

### Notes
- Toutes les affirmations des skills sont étiquetées `[OFFICIAL]` / `[SECONDARY]` / `[UNVERIFIED]`.
- Les seuils heuristiques (skill body > 8 KB = MEDIUM, etc.) sont calibrés sur l'observation de plugins communautaires, pas validés par Anthropic.
- Le plugin est conçu pour ne **rien modifier automatiquement** chez l'utilisateur.
