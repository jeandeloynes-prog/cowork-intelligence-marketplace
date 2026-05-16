---
name: cowork-graphify
description: Intégration Graphify Erudiam (knowledge graph code + docs) dans le workflow Claude Code / Cowork. Consulte le graphe AVANT toute écriture/modification de code ou de document, déclenche une re-indexation APRÈS. Supporte un graphe user (transverse) + un graphe par projet, configuré via `~/.claude/graphify-config.json`. Wrapper du MCP server `graphify-erudiam` avec ses 7 tools de lecture + script de refresh externe. Déclencheurs — "graphify", "consulter graphe", "knowledge graph", "indexer code", "indexer docs", "que sait Graphify", "construire le graphe", "ré-indexer", "ingest graphify", "structure du code", "imports d'un fichier", "appelants d'une fonction".
allowed-tools: Read, Grep, Glob, Bash
---

# Cowork — Graphify integration

> **Goal.** Make Graphify Erudiam a first-class citizen of the coding/writing workflow. Read the graph before changes, refresh it after.

---

## 1. Architecture en deux temps

```
   ┌─────────────────────────────────────────────────────────┐
   │ AVANT toute modification (code ou .md)                  │
   │                                                         │
   │   query_graph("<sujet du dev>")                         │
   │   → liste des entités impliquées, leurs voisins,        │
   │     leurs dépendances, leur communauté                  │
   │   → Claude voit ce qui existe avant de toucher          │
   └─────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌─────────────────────────────────────────────────────────┐
   │ MODIFICATION                                            │
   │   Edit / Write sur les fichiers ciblés                  │
   └─────────────────────────────────────────────────────────┘
                              │
                              ▼
   ┌─────────────────────────────────────────────────────────┐
   │ APRÈS modification                                      │
   │                                                         │
   │   /cowork-intelligence:cowork-graphify-refresh [scope]  │
   │   → re-indexe le graphe concerné (debounce 30 s)        │
   │   → la prochaine query reflète l'état réel              │
   └─────────────────────────────────────────────────────────┘
```

Deux scopes :
- **`user`** — graphe transverse, notes, savoirs, snippets partagés entre projets.
- **`<project-name>`** — graphe du repo courant. Identifié par le `basename` du dépôt git (ou par config explicite).

---

## 2. Surface MCP — les 7 tools de `graphify-erudiam`

Tous en **lecture seule**. La re-indexation passe par le CLI `graphify`, pas par le MCP.

| Tool | Usage typique |
|---|---|
| `graph_stats` | Vérifier la santé du graphe avant un audit (`nodes`, `edges`, `communities`, ratio EXTRACTED/INFERRED) |
| `god_nodes(top_n)` | Identifier les abstractions centrales d'un repo (les nodes les plus connectés) |
| `query_graph(question, mode, depth, token_budget)` | Recherche en langage naturel ou keyword. BFS pour contexte large, DFS pour tracer un chemin précis |
| `get_node(label)` | Tirer la fiche d'une entité (fonction, type, fichier, document) |
| `get_neighbors(label, relation_filter)` | Voisins directs + relations typées (`imports`, `calls`, `contains`, etc.) |
| `get_community(community_id)` | Tous les nodes d'un cluster — gros résultat, à utiliser sparingly |
| `shortest_path(from, to)` | Trace de dépendance entre deux entités |

---

## 3. Quand consulter Graphify (pattern de pré-développement)

**Toujours** :
1. Quand l'utilisateur demande de **modifier** un fichier existant → `get_node(<filename>)` puis `get_neighbors(<filename>)` pour voir ce qui en dépend.
2. Quand l'utilisateur demande de **créer** un nouveau fichier → `query_graph("<concept>")` pour vérifier qu'il n'existe pas déjà sous une autre forme.
3. Quand l'utilisateur demande une **revue** ou un **audit** d'une zone → `query_graph` + `get_community` sur les communautés impliquées.

**Souvent** :
4. Avant de proposer un design → `god_nodes(20)` pour comprendre les abstractions centrales déjà en place.
5. Avant de proposer un refactor → `shortest_path(<from>, <to>)` pour évaluer le blast radius.

**Rarement** :
6. Pour les modifications triviales (typo, format) → consultation Graphify = overhead inutile.

Règle de coût : chaque `query_graph` coûte ~500-2000 tokens selon `token_budget`. Utilise un budget bas (500) pour un check rapide, plus haut (2000-4000) pour un design.

---

## 4. Re-indexation — pattern de post-développement

Après toute modification non-triviale (Edit ou Write sur du code ou un .md indexé), invoquer :

```
/cowork-intelligence:cowork-graphify-refresh [scope]
```

- Sans argument : refresh du scope projet (cwd-based).
- `user` : refresh du scope user.
- `all` : refresh user + projet courant.

Le hook `PostToolUse` matcher `Edit|Write` peut déclencher automatiquement avec debounce (30 s) — voir `scripts/graphify_refresh.sh`.

**Important** : la re-indexation n'est pas gratuite (variable selon la taille du repo). Sur concours-eu (~16K nodes), le rebuild complet prend probablement plusieurs secondes. Le script utilise un debounce pour éviter de re-build à chaque keystroke.

---

## 5. Configuration utilisateur

Le plugin lit `~/.claude/graphify-config.json`. Format :

```json
{
  "binary": "/Users/admin/.local/bin/graphify",
  "scopes": {
    "user": {
      "command_args": ["build", "--graph-id", "user"],
      "data_dir": "/Users/admin/.claude/data/graphify-user",
      "source_dirs": [
        "/Users/admin/Documents/notes"
      ]
    },
    "concours-eu": {
      "command_args": ["build", "--graph-id", "concours-eu"],
      "data_dir": "/Users/admin/Documents/Claude/Projects/Erudiam/concours-eu/.graphify",
      "source_dirs": [
        "/Users/admin/Documents/Claude/Projects/Erudiam/concours-eu"
      ]
    }
  },
  "debounce_seconds": 30
}
```

Les `command_args` sont **à adapter à la vraie signature du CLI `graphify`** (à découvrir via `graphify --help`).

Si le fichier `graphify-config.json` n'existe pas → le plugin reste silencieux, aucune erreur, aucune action automatique. C'est la stratégie *graceful degradation*.

---

## 6. Honest gaps

Ce skill est conçu sur la base de l'observation du MCP server `graphify-erudiam` (16 492 nodes, 127 748 edges, graphe concours-eu) et du chemin du binaire `/Users/admin/.local/bin/graphify`. Mais :

- **La signature exacte de la CLI Graphify** n'a pas été vérifiée — les `command_args` du fichier de config sont des placeholders à remplacer après consultation de `graphify --help`.
- **Le support multi-graph** par une seule instance de Graphify n'a pas été vérifié. Si Graphify est mono-graphe, il faudra lancer deux instances (deux entrées dans `.mcp.json`) plutôt qu'une seule avec `--graph-id`.
- **L'invalidation du cache MCP** après une re-indexation n'est pas garantie — le MCP server peut renvoyer des résultats stale jusqu'à un cycle de réinitialisation. À tester côté Erudiam.

Pour ces 3 points : tester localement, puis ajuster `graphify-config.json` et éventuellement le script `scripts/graphify_refresh.sh`.

---

## 7. Sources

- MCP server `graphify-erudiam` (interne Erudiam)
- Observations live faites via `mcp__graphify-erudiam__*` dans cette session (cf. CHANGELOG v0.3.0)
- Pattern d'architecture knowledge-graph + LLM : Anthropic engineering blog, "context engineering" `[OFFICIAL]`
- MCP specification : [modelcontextprotocol.io](https://modelcontextprotocol.io/specification/2025-11-25) `[OFFICIAL]`
