---
description: Active ou désactive en bloc les 13 plugins claude-for-legal en patchant ~/.claude/settings.json. Backup automatique. À lancer suivi de /reload-plugins.
argument-hint: <on|off>
allowed-tools: Bash
---

Argument fourni : $ARGUMENTS

Procédure :

1. Si `$ARGUMENTS` n'est ni "on" ni "off", affiche l'usage exact (`/cowork-legal-mode <on|off>`) et stoppe.

2. Exécute le script bash livré avec le plugin :
   ```
   bash "$CLAUDE_PLUGIN_ROOT/scripts/toggle_legal_plugins.sh" $ARGUMENTS
   ```
   Ce script :
   - Vérifie la présence de `jq` (sinon abort avec message clair).
   - Sauvegarde `~/.claude/settings.json` vers `~/.claude/settings.json.bak.<timestamp>`.
   - Patche les 13 entrées `*@claude-for-legal` dans `enabledPlugins` à `true` ou `false` selon l'argument.
   - Valide le JSON produit avant de le remplacer.
   - Liste les clés modifiées.

3. Une fois le script terminé, affiche un rappel : "Plugins legal $ARGUMENTS. Tape **/reload-plugins** pour appliquer."

4. Si l'utilisateur veut restaurer la version précédente : `cp ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json` puis `/reload-plugins`.

Notes de sécurité :
- Le script ne modifie QUE les clés `*@claude-for-legal` dans `enabledPlugins`. Le reste de `settings.json` est préservé via `jq`.
- Un backup est créé à chaque exécution — facile à restaurer.
- Limitation : Claude Code n'expose pas d'API pour recharger les plugins programmatiquement. L'étape `/reload-plugins` reste manuelle.
