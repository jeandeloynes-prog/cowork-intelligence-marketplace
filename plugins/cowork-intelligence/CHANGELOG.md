# Changelog

Toutes les évolutions notables du plugin `cowork-intelligence` sont consignées ici.

Format : [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning : [SemVer](https://semver.org/spec/v2.0.0.html).

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
