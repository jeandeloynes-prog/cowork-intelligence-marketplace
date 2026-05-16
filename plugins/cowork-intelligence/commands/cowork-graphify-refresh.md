---
description: Re-indexe le knowledge graph Graphify pour un scope. Par defaut `graphify update` sur le projet courant (rapide, sans LLM). Force `graphify extract` pour un build initial (lent, avec LLM). Utilise `graphify global add/list` pour le scope user. Silent si binary `graphify` absent.
argument-hint: "project | extract | user | all (defaut project)"
allowed-tools: Bash
---

Argument fourni : $ARGUMENTS

Procédure :

1. Active la skill `cowork-graphify` si présente, ou s'appuie sur le skill officiel Graphify si déjà installé via `graphify install --platform claude`.

2. Exécute le script de refresh :
   ```bash
   bash "$CLAUDE_PLUGIN_ROOT/scripts/graphify_refresh.sh" $ARGUMENTS
   ```

3. Affiche la sortie. Interprétation :
   - `update '<scope>' OK in Ns` → re-extract incrémental réussi. Graphe à jour, **sans appel LLM** donc gratuit en tokens.
   - `extract '<scope>' OK in Ns` → build initial avec LLM. Plus lent + coût LLM. À ne lancer qu'une fois par projet.
   - `user/global OK in Ns` → paths du `~/.claude/graphify-config.json` ré-enregistrés, état global listé.
   - `refreshed Ns ago (debounce)` → normal, le debounce protège contre les re-builds en cascade.
   - Pas de sortie → binary `graphify` absent ou non exécutable, feature désactivée silencieusement.

4. Ne modifie jamais `~/.claude/graphify-config.json` automatiquement.

Sous-commandes Graphify utilisées par ce wrapper (vérifiées via `graphify --help`) :
- `graphify update` (rapide, sans LLM) — pour les refresh post-edit.
- `graphify extract <path>` (lent, avec LLM) — uniquement pour un premier build.
- `graphify global add <path>` (idempotent) — pour le scope user / cross-repo.
- `graphify global list` — pour voir l'état du graphe global.

Alternative à ce wrapper : `graphify watch` (daemon natif Graphify qui re-indexe en continu). Si tu lances `graphify watch` dans un terminal séparé, le hook `PostToolUse` de ce plugin devient redondant et tu peux désactiver l'auto-refresh en supprimant `~/.claude/graphify-config.json`.
