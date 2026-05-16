---
name: cowork-skills-hooks-mcp
description: Architecture pratique des skills, hooks et MCP — frontmatter SKILL.md, progressive disclosure, design d'une description efficace, événements de hooks et codes de retour, format .mcp.json, transports stdio/Streamable HTTP, choix entre skill/hook/MCP/subagent/command, anti-patterns. Déclencheurs — "écrire un skill", "créer un hook", "ajouter un MCP", "skill ne déclenche pas", "hook block", "PreToolUse", "PostToolUse", "mcp.json", "stdio vs HTTP", "skill description", "frontmatter SKILL.md", "skill vs command", "skill vs subagent".
allowed-tools: Read, Write, Edit, Grep, Glob, WebFetch
---

# Skills, Hooks & MCP — Practical Architecture

> **Goal.** Concrete patterns for designing each extension point, with verified shapes from Anthropic docs and clearly flagged uncertainty. Use this skill when you are *writing* a skill / hook / MCP server, not just reasoning about one.

---

## 1. SKILL.md — anatomy that actually works

### 1.1 Frontmatter — only the fields known to be honored

```yaml
---
name: my-skill                     # OFFICIAL — should match folder name; lowercase, hyphens
description: |                     # OFFICIAL — single most important field
  One-sentence purpose, then a "Triggers" line of concrete keywords.
allowed-tools: Read, Grep, WebFetch    # OFFICIAL — comma- or space-separated tool names
disable-model-invocation: false    # OFFICIAL — true blocks auto-load (user must invoke)
---
```

Fields commonly seen in community plugins but **NOT confirmed in primary Anthropic docs** at time of writing: `license`, `version`, `author`, `aliases`. Treat them as ignored-but-tolerated metadata.

Source: [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`.

### 1.2 The description is your trigger surface

Claude reads **every** registered skill's description on every turn to decide whether to load the body. This means:

- **Description ≈ index entry**, not a marketing tagline.
- Front-load the concrete *nouns and verbs* the user is likely to use.
- Anthropic engineering blog explicitly recommends including "the problem it solves" rather than "what it does" `[OFFICIAL]`.

**Pattern that works** (used by `anthropic-skills/*` and by this plugin):

```
description: <one sentence purpose>. Déclencheurs — "phrase 1", "phrase 2", "phrase 3", ...
```

The "Triggers" / "Déclencheurs" list is informal but observably improves triggering across community plugins.

**Anti-pattern**:
```
description: An advanced enterprise-grade comprehensive framework...   ← no keywords, won't trigger
```

### 1.3 Progressive disclosure

Anthropic positions skills as **progressive disclosure** — Claude reads the description, then if relevant loads `SKILL.md`, then if needed reads adjacent files (`references/`, `scripts/`, `assets/`). This is described in [Equipping agents](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`.

Practical layout:

```
skills/my-skill/
├── SKILL.md                # < 500 lines ideally; the entry point
├── references/             # deep-dive markdown the model reads on demand
│   ├── api-shapes.md
│   └── error-codes.md
├── scripts/                # executable helpers Claude can run
│   └── parse-config.py
└── assets/                 # templates, schemas
    └── boilerplate.json
```

Anthropic does **not** document this folder layout as enforced — it's the community convention used inside `anthropic-skills/*`. The model can read whatever Bash/Read can reach, so layout is mostly about *your* maintainability.

### 1.4 Sizing rules of thumb

| Skill body size | Effect |
|---|---|
| < 100 lines | Cheap; loads quickly; risk = under-specified |
| 100–500 lines | Sweet spot for most domain skills |
| 500–2 000 lines | Acceptable if the skill is rarely loaded; otherwise factor into `references/` |
| > 2 000 lines | Almost always a refactor signal — split or push to `references/` |

These thresholds are **community heuristics, not Anthropic numbers** `[SECONDARY]`. The hard cost is: every loaded skill body consumes the rest of the turn's context window.

### 1.5 Decision: skill vs command vs subagent

| Question | If yes → |
|---|---|
| Should Claude apply this **without being asked**, when context matches? | Skill |
| Does the user need to **deliberately trigger** the same prompt? | Slash command |
| Does the work need a **fresh context** and return a small summary? | Subagent |
| Is it a **side-effect at an event**, not a piece of knowledge? | Hook |

---

## 2. Hooks — deterministic event handlers

### 2.1 Events confirmed in official docs

From [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) `[OFFICIAL]`:

| Event | Fires when |
|---|---|
| `PreToolUse` | After tool args are resolved, before the tool runs |
| `PostToolUse` | After a tool returns successfully |
| `UserPromptSubmit` | After the user submits a prompt, before Claude sees it |
| `SessionStart` | When a session begins |
| `SessionEnd` | When a session ends |

Events frequently referenced by community plugins but **not confirmed against primary docs** at time of writing: `Stop`, `SubagentStop`, `PreCompact`, `Notification`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`. They may exist — verify against the live docs before relying on them. `[UNVERIFIED]`

### 2.2 Configuration shape

A `hooks.json` block (or `hooks` key inside `plugin.json` / `.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PLUGIN_ROOT/hooks/block_dangerous_bash.sh"
          }
        ]
      }
    ]
  }
}
```

- `matcher` matches the **tool name** for tool-related events; `"*"` matches all.
- `type` known values: `"command"`. Other types (`"http"`, `"mcp_tool"`, `"prompt"`) are mentioned in community plugins — **not all confirmed in primary docs** `[UNVERIFIED]`.
- Inside `command`, `$CLAUDE_PLUGIN_ROOT` resolves to the plugin's install directory.

### 2.3 Hook return contract

A `command` hook communicates via:
1. **Exit code 0** → allow / continue (default).
2. **Exit code non-zero** → block; stdout/stderr surfaced to Claude / user.
3. **Structured JSON on stdout** for richer control. The shape seen in community plugins:

```json
{
  "continue": true,
  "stopReason": "string shown if continue=false",
  "suppressOutput": false
}
```

Anthropic docs confirm `continue` and `stopReason` semantics `[OFFICIAL]`. Other fields (`suppressOutput`, `additionalContext`) are community-observed `[UNVERIFIED]` — test on your version.

### 2.4 Useful hook patterns

| Pattern | Event | Purpose |
|---|---|---|
| Token budget warning | `UserPromptSubmit` | Inject a brief note if session is approaching context limit |
| Dangerous-command guard | `PreToolUse` matcher `Bash` | Block `rm -rf /`, force confirmation on `sudo`, etc. |
| Audit log | `PostToolUse` matcher `*` | Append tool name + args hash to `~/.claude/audit.log` |
| Skill conflict detector | `SessionStart` | Run a script that scans loaded skills for duplicate triggers, prints a warning |
| Repo lint gate | `PreToolUse` matcher `Edit\|Write` | Block writes that would break a known invariant |

### 2.5 Hooks that are **toxic** to avoid

- **Verbose `PostToolUse` hooks**: every line of stdout becomes context cost. Keep < 5 lines or use `suppressOutput`.
- **Slow synchronous hooks** in `PreToolUse`: they delay every tool call. Stay < 500 ms or move to async telemetry.
- **Hooks that mutate prompts silently**: erode debuggability; if you must, log what you mutated.
- **HTTP hooks to flaky endpoints without timeouts**: can stall the entire session.

---

## 3. MCP — out-of-process tools and resources

### 3.1 Spec basics (verified)

From [MCP specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) `[OFFICIAL]`:

- JSON-RPC 2.0 over the chosen transport.
- **Server primitives**: `tools`, `resources`, `prompts`.
- **Client primitives**: `roots`, `sampling`, `elicitation` (added in `2025-06-18`).

From [Transports spec](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) `[OFFICIAL]`:

| Transport | Status | When to use |
|---|---|---|
| `stdio` | Recommended | Local subprocess; simplest; almost all local MCP servers |
| `Streamable HTTP` | Recommended | Remote or networked services; replaces SSE-only since `2025-03-26` |
| HTTP+SSE (old) | **Deprecated** since `2025-03-26` | Avoid for new servers |

### 3.2 `.mcp.json` shape

Project-scoped, lives at the project root (or `.claude/.mcp.json`):

```json
{
  "mcpServers": {
    "graphify": {
      "command": "node",
      "args": ["/path/to/graphify-mcp/dist/index.js"],
      "env": {
        "GRAPHIFY_API_KEY": "${GRAPHIFY_API_KEY}"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    }
  }
}
```

The same `mcpServers` block can live inside `plugin.json` when shipped as part of a plugin.

### 3.3 Where MCP cost hides

**MCP servers are not free.** Their tool descriptions are typically loaded into the system area on session start. A server exposing 50 tools with verbose descriptions can easily cost 5 000–10 000 tokens *per turn* — multiplied by every turn of every session, this dominates other optimizations.

Mitigations:
1. **Curate tool count.** Prefer 3–10 focused tools over a "kitchen-sink" server.
2. **Tighten descriptions.** One sentence, one example.
3. **Use Tool Search Tool / dynamic discovery** if your harness supports the [advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use) beta `[OFFICIAL]`.
4. **Split MCPs by domain** and enable only what the session needs.

### 3.4 MCP red flags during audit

- Server exposing > 30 tools with no grouping.
- Tool description that includes a manual / changelog.
- Tools that return > 10 KB by default (force pagination / summary mode).
- Server doing privileged actions without `PermissionRequest`-style consent.
- Server with no schema for inputs — Claude has to guess and burns retries.

---

## 4. Choosing the right shape — decision tree

```
Is it knowledge / a recipe / a pattern?
├── Yes → SKILL  (with focused description, references/ for depth)
└── No
    Is it a one-shot prompt the user types?
    ├── Yes → SLASH COMMAND  (with argument-hint)
    └── No
        Does it need a fresh context window and a summary back?
        ├── Yes → SUBAGENT
        └── No
            Is it tied to a specific runtime event?
            ├── Yes → HOOK  (matcher + small command)
            └── No
                Does it provide tools / live data / external state?
                ├── Yes → MCP SERVER  (curate tools, watch token cost)
                └── No → it's probably just a doc — add to CLAUDE.md or README
```

---

## 5. Honest gaps

- **Exact MCP descriptions caching behavior** in Claude Code: not verified.
- **Whether hooks can mutate the user prompt before Claude sees it** (`UserPromptSubmit` modify mode): community plugins do it, but the official doc doesn't explicitly describe a write-back contract.
- **Schema for `marketplace.json`** to publish a plugin: examples exist in GitHub plugin repos, but Anthropic's official schema page was not located during research.

When in doubt: read the relevant page on [docs.claude.com](https://docs.claude.com) directly and test on a throwaway plugin before shipping.

---

## 6. Sources

- [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`
- [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) `[OFFICIAL]`
- [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) `[OFFICIAL]`
- [Subagents](https://docs.claude.com/en/docs/claude-code/sub-agents) `[OFFICIAL]`
- [MCP in Claude Code](https://docs.claude.com/en/docs/claude-code/mcp) `[OFFICIAL]`
- [MCP spec 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) `[OFFICIAL]`
- [MCP transports 2025-03-26](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) `[OFFICIAL]`
- [Introducing advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use) `[OFFICIAL]`
