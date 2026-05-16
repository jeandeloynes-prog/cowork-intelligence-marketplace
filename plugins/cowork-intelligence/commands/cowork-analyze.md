---
description: Audit complet d'un setup Claude Code / Cowork (skills, hooks, MCP, CLAUDE.md, commands). Produit un rapport priorisé avec correctifs.
argument-hint: [chemin optionnel — par défaut le repo courant]
allowed-tools: Read, Grep, Glob, Bash
---

Active la skill `cowork-analysis-engine` et exécute un **audit complet** du setup Claude Code / Cowork.

Cible à analyser : $ARGUMENTS

Si aucun chemin n'est fourni, audite le repo courant et le scope utilisateur (`~/.claude/`).

Procédure :
1. Inventorier skills, CLAUDE.md, MCP servers, hooks, slash commands, plugins.
2. Détecter redondances, conflits de triggers, contradictions.
3. Détecter le token bloat (skill body trop gros, CLAUDE.md trop gros, MCP bavards).
4. Détecter les descriptions faibles ou collidant.
5. Détecter les anti-patterns (hooks sans timeout, MCPs sans schema, etc.).
6. Émettre le rapport au format demandé par la skill `cowork-analysis-engine` (table groupée par sévérité + recommandations priorisées).

Important :
- N'invente aucun fichier.
- Cite les chemins exacts et les tailles mesurées.
- Ne modifie ni ne supprime rien — propose uniquement.
