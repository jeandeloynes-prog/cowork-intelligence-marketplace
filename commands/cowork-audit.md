---
description: Audit gouvernance et maintenabilité — versionning, CHANGELOG, sources MCP, schemas, conventions de nommage, drift potentiel. Pas de focus token.
argument-hint: [chemin optionnel]
allowed-tools: Read, Grep, Glob, Bash
---

Active la skill `cowork-observability-governance` et `cowork-analysis-engine`.

Cible : $ARGUMENTS (par défaut : repo courant).

Focalise l'audit sur la gouvernance et la maintenabilité, PAS sur le coût :

1. Pour chaque plugin trouvé : présence et validité de `plugin.json`, champ `version` (semver), `description`, `keywords`, `license`.
2. Pour chaque plugin : présence d'un `CHANGELOG.md`. Si absent, signaler.
3. Pour chaque skill : présence de `name`, `description` (≥ 80 caractères), `allowed-tools`. Frontmatter YAML valide.
4. Pour chaque MCP server : `command`, `args`, schema d'inputs sur les tools (si lisible). Signaler les tools sans schéma.
5. Pour chaque hook : type connu (`command`), timeout implicite, présence d'une variable `$CLAUDE_PLUGIN_ROOT` plutôt qu'un chemin codé en dur.
6. Pour chaque slash command : `description`, `argument-hint` si arguments attendus.
7. Conventions de nommage : skills en kebab-case, commands en kebab-case, dossiers cohérents.

Émets un rapport au format markdown :
- Section "Conformité plugin manifest"
- Section "Conformité skills"
- Section "Conformité hooks / MCP / commands"
- Section "Drift signals" (skills jamais déclenchés / MCPs jamais appelés si transcripts disponibles)
- Section "Actions recommandées" (priorité gouvernance)

Ne supprime ni ne modifie rien — propose uniquement.
