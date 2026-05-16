---
description: Déclenche la re-indexation du knowledge graph Graphify pour un scope donné (user, project, all). Lit la config ~/.claude/graphify-config.json, applique un debounce (par défaut 30s), exécute le CLI configuré. Silent si la config n'existe pas.
argument-hint: "[scope: project | user | all | nom-projet] — defaut cwd"
allowed-tools: Bash
---

Argument fourni : $ARGUMENTS

Procédure :

1. Active la skill `cowork-graphify` pour le contexte.

2. Exécute le script de refresh :
   ```bash
   bash "$CLAUDE_PLUGIN_ROOT/scripts/graphify_refresh.sh" $ARGUMENTS
   ```

3. Affiche la sortie. Si le script reporte :
   - `scope '<X>' OK in Ns` → confirme à l'utilisateur que la mémoire Graphify est à jour.
   - `scope '<X>' not configured` → suggère d'ajouter une entrée dans `~/.claude/graphify-config.json`.
   - `scope '<X>' refreshed Ns ago (debounce)` → c'est normal, le debounce protège contre les re-builds en cascade.
   - `scope '<X>' FAILED` → indique le code retour ; ne propose PAS de fix automatique.

4. Ne modifie jamais `~/.claude/graphify-config.json` automatiquement — c'est à l'utilisateur de l'éditer.

Notes :
- Le MCP server `graphify-erudiam` peut renvoyer des résultats légèrement stale après une re-indexation (cache interne possible). Une seconde `query_graph` quelques secondes plus tard reflète généralement l'état neuf.
- La re-indexation peut durer plusieurs secondes voire minutes selon la taille du scope. Le script garde stdout court.
