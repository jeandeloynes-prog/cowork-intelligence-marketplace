---
description: Audit ciblé sur la consommation de tokens — skills trop volumineuses, CLAUDE.md trop gros, MCP bavards, redondances coûteuses. Produit un plan de réduction priorisé.
argument-hint: [chemin optionnel]
allowed-tools: Read, Grep, Glob, Bash
---

Active les skills `cowork-context-token-optimization` et `cowork-analysis-engine`.

Cible : $ARGUMENTS (par défaut : repo courant + scope utilisateur).

Concentre-toi UNIQUEMENT sur les findings liés au coût en tokens :
- Skill body > 8 KB (signaler), > 20 KB (urgent).
- CLAUDE.md > 4 KB (signaler), > 8 KB (urgent).
- MCP server > 30 tools, ou tools dont la description dépasse 500 caractères.
- Redondances entre skills (déclencheurs qui se chevauchent).
- Skills loadées systématiquement mais peu utilisées (si l'utilisateur fournit des transcripts).
- Hooks bavards (PostToolUse qui ajoutent > 5 lignes au contexte).

Pour chaque finding :
1. Le chemin exact.
2. La mesure (bytes / tokens estimés à 4 bytes/token).
3. La correction la plus petite possible (trim, split vers references/, suppression, déclenchement plus restrictif).
4. L'économie estimée.

Termine par un plan d'action en 3 ou 5 étapes ordonnées par ROI tokens/effort.

Ne propose pas de réécriture massive si un simple trim suffit.
