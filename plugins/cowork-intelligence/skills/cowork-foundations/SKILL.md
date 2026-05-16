---
name: cowork-foundations
description: Fondamentaux Claude Code / Claude Cowork — vocabulaire, hiérarchie d'instructions (system prompt, CLAUDE.md, skills, hooks, commands), cycle de vie d'une session, ordre d'exécution, comportement runtime, distinction skills vs subagents vs commands vs MCP. Déclencheurs — "comment fonctionne Claude Code", "qu'est-ce qu'un skill", "différence skill subagent command", "ordre des instructions", "hiérarchie système", "lifecycle session", "CLAUDE.md", "vocabulaire Cowork", "fondamentaux agent".
allowed-tools: Read, Grep, Glob, WebFetch
---

# Claude Code / Cowork — Foundations

> **Goal.** Establish a shared, source-cited vocabulary for everything else in this plugin. Read this skill first when in doubt about *what something is*.
>
> **Rigor rule.** Every claim here is tagged `[OFFICIAL]` (Anthropic primary docs / engineering blog / GitHub repo `anthropics/*`), `[SECONDARY]` (third-party blog or community), or `[UNVERIFIED]`. If a property cannot be confirmed against a primary source, this skill says so explicitly.

---

## 1. Product surface — terms that get confused

| Term | What it is | Primary source |
|---|---|---|
| **Claude API / Claude Platform** | The HTTP API and SDKs exposing Claude models. | [Anthropic API docs](https://docs.claude.com/) `[OFFICIAL]` |
| **Claude Code** | CLI / IDE-integrated coding agent built on the Claude API. Loads plugins, skills, hooks, slash commands, MCP servers, CLAUDE.md. | [Claude Code docs](https://docs.claude.com/en/docs/claude-code/overview) `[OFFICIAL]` |
| **Claude Cowork** | Desktop UI built on top of Claude Code / Claude Agent SDK for non-developer workflows. Same plugin / skill / MCP model. | Cowork system prompt (current session) `[OFFICIAL — runtime]` |
| **Claude Agent SDK** | Renamed from "Claude Code SDK" on **29 September 2025** alongside Claude Sonnet 4.5. Python: `claude-agent-sdk`. TypeScript: `@anthropic-ai/claude-agent-sdk`. | [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) `[OFFICIAL]` ; [Migration guide](https://platform.claude.com/docs/en/agent-sdk/migration-guide) `[OFFICIAL]` |

> ⚠️ **Common confusion.** "Claude" in casual speech = whichever surface (web app, Cowork, Code, API). Always disambiguate when discussing prompt behavior — the *system prompt and harness differ per surface*.

---

## 2. Instruction layers — what overrides what

Claude assembles its working context from layers. The **upper layers** in the stack below are added first by the harness and tend to be most authoritative; the model itself doesn't enforce a strict precedence, but Anthropic's harnesses (Claude Code, Cowork) place layers in a deterministic order.

```
┌──────────────────────────────────────────────────────────┐
│  1. Model system prompt (built into harness)             │  ← cannot be edited
│  2. Plugin / skill instructions when triggered           │  ← progressive
│  3. CLAUDE.md (enterprise → user → project)              │  ← persistent
│  4. Slash command body (when invoked)                    │  ← ephemeral
│  5. User message + tool results                          │  ← turn-by-turn
└──────────────────────────────────────────────────────────┘
```

- **Order of CLAUDE.md** files is hierarchical: enterprise > user (`~/.claude/CLAUDE.md`) > project (`./CLAUDE.md`). All present files are concatenated. Source: [Claude Code memory docs](https://docs.claude.com/en/docs/claude-code/memory) `[OFFICIAL]`.
- In **Claude Agent SDK** specifically, `CLAUDE.md` is **NOT loaded by default**. You must set `settingSources: ['project']` (TS) or `setting_sources=["project"]` (Python). Source: [Agent SDK migration guide](https://platform.claude.com/docs/en/agent-sdk/migration-guide) `[OFFICIAL]`.
- HTML comments (`<!-- ... -->`) inside CLAUDE.md are **stripped before injection** `[SECONDARY — community-reported, not in primary doc]`. Treat as best practice but verify before relying on for secrets.

---

## 3. Building blocks — the five extension points

### 3.1 Skill (`SKILL.md`)
- A Markdown file with YAML frontmatter, discovered by the harness.
- **Model-invoked**: Claude reads the description of every available skill and decides whether to load the body. This is the "progressive disclosure" pattern documented in the Anthropic engineering blog [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`.
- Frontmatter fields confirmed in official docs: `name`, `description`, `allowed-tools`, `disable-model-invocation`. Other fields (`license`, `version`, `author`) appear in community plugins — **NOT confirmed in primary docs** `[UNVERIFIED]`.
- The description is the **only thing Claude reads to decide whether to load the skill body**. Description = trigger surface. Body = payload.

### 3.2 Subagent (`agents/*.md`)
- A separate Claude instance with its own context window, invoked by the main agent.
- Used for **context isolation** (return a summary, not full history).
- Documented in [Subagents](https://docs.claude.com/en/docs/claude-code/sub-agents) `[OFFICIAL]`.

### 3.3 Slash command (`commands/*.md`)
- A reusable prompt template. **User-invoked only** (no model-invocation).
- Variables: `$ARGUMENTS`, `$1..$N`. Frontmatter supports `description`, `argument-hint`, `allowed-tools`. Source: [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) `[OFFICIAL]`.

### 3.4 Hook (`hooks/hooks.json` or inline in `plugin.json`)
- Event-driven shell command / HTTP call / MCP tool / prompt. Runs deterministically around specific runtime events.
- Documented events include `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`. Source: [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) `[OFFICIAL]`.
- Additional events (`Stop`, `SubagentStop`, `PreCompact`, `Notification`) are referenced in community plugins; **whether all are stable / documented today is non-verified** `[UNVERIFIED]` — check the live docs before relying on them.

### 3.5 MCP server (declared in `.mcp.json` or `plugin.json.mcpServers`)
- Out-of-process tool/resource provider speaking JSON-RPC 2.0 over stdio or Streamable HTTP.
- Spec: [modelcontextprotocol.io/specification/2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) `[OFFICIAL]`.
- The `SSE`-only transport from `2024-11-05` is **deprecated** since `2025-03-26` — replaced by Streamable HTTP. Source: [Transports spec](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) `[OFFICIAL]`.

---

## 4. Decision matrix — which extension point for what

| Need | Use |
|---|---|
| Knowledge / pattern Claude should auto-apply when context matches | **Skill** |
| Reusable prompt the user types deliberately | **Slash command** |
| Heavy computation or long context that would pollute the main thread | **Subagent** |
| Deterministic side-effect tied to an event (log, validate, abort) | **Hook** |
| Stateful tool, data source, or external system | **MCP server** |
| Persistent project-wide instruction | **CLAUDE.md** |

Anti-patterns:
- **Skill that should be a command**: if Claude shouldn't decide *when*, don't pay the description-load cost. Use a command.
- **Command that should be a skill**: if the user shouldn't have to remember to invoke it, make it a skill.
- **Hook that should be a skill**: if it's about *what to do* rather than *when something fires*, it's a skill.
- **MCP that should be a script**: if it's pure local I/O with no real-time state, a bash script the user runs is cheaper and more debuggable.

---

## 5. Session lifecycle (Claude Code, simplified)

```
launch → SessionStart hook → load CLAUDE.md → register skills/commands/MCP
        → user prompt → UserPromptSubmit hook
        → reasoning loop:
              tool call → PreToolUse hook → execute tool → PostToolUse hook
              skill auto-load (if description matches)
              subagent dispatch (if needed)
        → response → next prompt or SessionEnd
```

Each loop iteration consumes from the model's context window. Once close to the limit, Claude Code triggers **compaction** — a summarization pass. The `PreCompact` hook fires (when supported) and lets you snapshot state.

---

## 6. What costs tokens (and what doesn't)

Token cost on a given turn = roughly:

```
(system prompt) + (all loaded skill bodies) + (CLAUDE.md) + (full conversation so far) + (current user msg)
```

- **Loaded skill body** is added once when triggered, but stays in context for the rest of the turn. The **description** of every available skill is in the system area on every turn (small but non-zero).
- **MCP tool descriptions** are loaded eagerly on session start in most harnesses. A noisy MCP server with 50 tool definitions costs tokens on *every turn* whether or not you use it.
- **Hooks** themselves cost nothing in tokens — they run outside the model. Their *output* costs tokens only if it's fed back in (e.g. `UserPromptSubmit` appending context).
- **CLAUDE.md** is added once per turn. A 5 KB CLAUDE.md ≈ 1 250 tokens on every turn for the entire session.
- **Prompt caching** can dramatically reduce the cost of stable prefixes. See `cowork-context-token-optimization` for numbers.

---

## 7. Reading list (primary sources)

1. [Claude Code overview](https://docs.claude.com/en/docs/claude-code/overview) `[OFFICIAL]`
2. [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) `[OFFICIAL]`
3. [Memory / CLAUDE.md](https://docs.claude.com/en/docs/claude-code/memory) `[OFFICIAL]`
4. [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) `[OFFICIAL]`
5. [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) `[OFFICIAL]`
6. [MCP in Claude Code](https://docs.claude.com/en/docs/claude-code/mcp) `[OFFICIAL]`
7. [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`
8. [Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents) `[OFFICIAL]`
9. [Effective context engineering for AI agents (29 Sept 2025)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) `[OFFICIAL]`
10. [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]`
11. [MCP specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) `[OFFICIAL]`

---

## 8. Honest gaps

Things this skill **does not assert** because they were not verified against primary sources during research:
- Maximum description length for `SKILL.md`. Anthropic engineering blog implies "concise" but gives no hard limit.
- Whether `disable-model-invocation: true` blocks just auto-load or also direct user invocation.
- Exact precedence between project / user / enterprise CLAUDE.md when both define the same instruction (cascade order is documented; collision behavior is not).
- Whether MCP tool descriptions are subject to prompt caching by default in Claude Code.

When asked about any of these, say "I don't know — please check the live docs at the link above."
