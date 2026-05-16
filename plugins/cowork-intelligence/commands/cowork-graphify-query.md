---
description: Interroge le knowledge graph Graphify Erudiam (via MCP graphify-erudiam) avant un dev. Wrapper convivial qui prend une question en langage naturel et appelle query_graph avec un budget de tokens raisonnable.
argument-hint: "question ou mot-cle [depth=2] [budget=1500]"
allowed-tools: Bash, mcp__graphify-erudiam__query_graph, mcp__graphify-erudiam__get_node, mcp__graphify-erudiam__get_neighbors
---

Argument fourni : $ARGUMENTS

Procédure :

1. Active la skill `cowork-graphify` pour le contexte d'utilisation.

2. Parse `$ARGUMENTS` :
   - Premier segment = la question en langage naturel.
   - Optionnel `depth=N` (par défaut 2, max 6).
   - Optionnel `budget=N` (par défaut 1500 tokens, max 4000).

3. Appelle `mcp__graphify-erudiam__query_graph` avec :
   - `question` = le segment principal
   - `mode` = `"bfs"` (contexte large par défaut ; `"dfs"` si l'utilisateur précise "tracer", "chemin", "path")
   - `depth` = la valeur parsée
   - `token_budget` = la valeur parsée

4. Si la réponse mentionne des nodes intéressants, propose à l'utilisateur d'appeler `get_node` ou `get_neighbors` sur les plus pertinents — ne le fais pas automatiquement (économie de tokens).

5. Synthétise en 3-5 lignes ce qui ressort, en citant explicitement les `src=<chemin>` retournés. Mentionne explicitement si certaines zones du graphe sont vides ou très denses (signal pour le dev à venir).

Anti-patterns à éviter :
- Ne pas refaire des appels successifs si le premier suffit. Le coût est réel.
- Ne pas appeler `get_community` sauf demande explicite — la réponse peut dépasser 100K caractères et nécessite un Read par chunks.
- Ne pas inventer de nodes ou de relations : ne reporte que ce que le MCP a réellement retourné.
