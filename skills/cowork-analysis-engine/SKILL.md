---
name: cowork-analysis-engine
description: Audit automatique d'un setup Claude Code / Cowork — scanne skills, hooks, MCP, CLAUDE.md, plugins ; détecte redondances, duplications, conflits de triggers, surcoûts tokens, fragmentation excessive, descriptions trop génériques, MCP bavards ; produit un rapport priorisé avec corrections proposées. Déclencheurs — "audit cowork", "audit claude code", "analyse mes skills", "détecter conflits skills", "scan plugins", "redondance skill", "duplications", "skill conflict", "trigger collision", "token audit", "MCP audit", "claude.md audit", "review setup".
allowed-tools: Read, Grep, Glob, Bash
---

# Analysis Engine — Audit your Claude Code / Cowork setup

> **Goal.** When triggered, perform a complete audit of the user's current Claude Code / Cowork installation and emit a prioritized, actionable report. Behave like a static analyzer for an agentic system.

---

## 1. Scope

When this skill loads, treat the following as the audit surface:

| Source | Paths to scan |
|---|---|
| Project skills | `./.claude/skills/**/SKILL.md` and plugin skills directories under `~/.claude/plugins/**/skills/**/SKILL.md` |
| User skills | `~/.claude/skills/**/SKILL.md` |
| Project CLAUDE.md | `./CLAUDE.md`, `./.claude/CLAUDE.md` |
| User CLAUDE.md | `~/.claude/CLAUDE.md` |
| MCP config | `./.mcp.json`, `./.claude/.mcp.json`, `~/.claude/.mcp.json` |
| Hooks | `./.claude/settings.json`, `./.claude/settings.local.json`, plugin `hooks/hooks.json` |
| Slash commands | `./.claude/commands/**/*.md`, `~/.claude/commands/**/*.md`, plugin `commands/` |
| Plugin manifests | `**/.claude-plugin/plugin.json` |

If a path doesn't exist, skip silently — don't fabricate findings.

---

## 2. Audit procedure

### 2.1 Step 1 — Inventory
Produce a flat inventory:

```
Skills        : N total (P project, U user, plugin breakdown)
CLAUDE.md     : sizes in bytes for each present file
MCP servers   : list with command, args, env keys (redact values)
Hooks         : count per event
Slash commands: count per scope
```

Cite the actual paths. **Never invent files that aren't there.**

### 2.2 Step 2 — Detect redundancies
For each pair of skills, compare:
- **Description token overlap**: if the same trigger keywords appear in ≥ 3 skills, flag as a triggering collision risk.
- **Body content overlap**: if two SKILL.md files share > 200 contiguous bytes of body, flag as duplication.
- **Conflicting guidance**: if one skill says "always X" and another says "never X" on the same topic, flag as a contradiction.

### 2.3 Step 3 — Detect token bloat
For each item:
- Skill body > 20 KB → **HIGH** (split or move to references/).
- Skill body > 8 KB → **MEDIUM** (consider trimming).
- CLAUDE.md file > 8 KB → **HIGH**.
- CLAUDE.md file > 4 KB → **MEDIUM**.
- MCP server with > 30 tools → **HIGH** (use Tool Search Tool or split server).
- MCP tool description > 500 characters → **MEDIUM**.

These thresholds are heuristics, not Anthropic-mandated. Justify each finding with the measured byte count.

### 2.4 Step 4 — Detect weak descriptions
For each skill description, flag:
- Length < 80 characters → **HIGH** (likely won't trigger reliably).
- No explicit trigger phrases / "Déclencheurs" / "Triggers" section → **MEDIUM**.
- Generic verbs only ("helps with", "assists in", "for tasks related to") → **MEDIUM**.
- Same opening 50 characters as another skill → **MEDIUM** (will confuse the matcher).

### 2.5 Step 5 — Detect dead weight
- Skill that hasn't appeared in any conversation transcript in 90 days → **LOW** (suggest removal).
- MCP tool that has zero invocations in 30 days → **LOW** (suggest removal).
- Hook that never fires (matcher mismatch) → **MEDIUM**.

You only have access to transcript data if the user provides it; do not invent usage history.

### 2.6 Step 6 — Detect anti-patterns
| Pattern | Severity |
|---|---|
| Skill body restates description | MEDIUM |
| CLAUDE.md duplicates README content | LOW |
| Hook of type `command` running unbounded shell with no timeout | HIGH |
| `disable-model-invocation: true` on a skill with no `/skill:` user instructions | LOW |
| Two skills with `allowed-tools` including `Bash` that overlap on triggers | MEDIUM |
| MCP server with no input schema on tools | HIGH |
| Plugin missing `version` in `plugin.json` | LOW |

---

## 3. Report shape

Emit findings as a markdown table grouped by severity:

```markdown
# Cowork Setup Audit — <date>

## Summary
- N skills, M MCP servers, K hooks, L commands
- Estimated per-turn cost (rough): X KB of stable context

## Findings
| Severity | Category | File | Issue | Suggested fix |
|---|---|---|---|---|
| HIGH | token-bloat | skills/foo/SKILL.md | 32 KB body | Split into references/ |
| HIGH | mcp-cost | .mcp.json:bar | 47 tools | Enable Tool Search or split server |
| MEDIUM | trigger-collision | skills/a, skills/b | both trigger on "audit" | Tighten one description |
| LOW | dead | commands/legacy.md | last edited 2024 | Confirm still needed |

## Recommendations (priority order)
1. ...
2. ...
```

Always:
- Cite the exact file path.
- Include the measured number (bytes, count) that justified the finding.
- Suggest the smallest possible fix (don't propose rewrites when a trim will do).

---

## 4. Heuristic budgets

For the "Estimated per-turn cost" line, use this rough model:

```
per_turn_overhead_bytes
  = sum(SKILL.md description bytes for every registered skill)
  + sum(CLAUDE.md cascade bytes)
  + sum(MCP tool description bytes for every registered tool)
  + harness system prompt (assume ~8 KB; cannot be measured without API access)
```

Convert to tokens with the rough 4 bytes ≈ 1 token rule (English; lower for code-heavy text). State that this is an estimate.

---

## 5. Things this skill must NOT do

- **Don't invent file contents.** If `cat` returns empty, say "empty file" — don't fabricate.
- **Don't propose rewrites you haven't read end-to-end.** Trim suggestions are fine; full rewrites require the user's go-ahead.
- **Don't delete anything.** Suggest deletion; let the user execute.
- **Don't change anything in `~/.claude/` without explicit user consent.** User-scoped files affect all of their work.

---

## 6. When to invoke a subagent

If the audit reveals > 50 skills or > 10 MCP servers, propose dispatching the deep analysis to a subagent so the main thread stays uncluttered. Pattern:

```
"Your setup has 87 skills. I'll dispatch a subagent to analyze them and return a compact summary. Proceed?"
```

This is consistent with the sub-agent architecture pattern documented by Anthropic for [context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) `[OFFICIAL]`.

---

## 7. Slash command companions

This skill is wired to three companion slash commands shipped with this plugin:

- `/cowork-analyze` — runs the full audit.
- `/cowork-optimize` — focuses on token-cost findings only.
- `/cowork-audit` — produces a governance-only report (versions, changelog gaps, missing schemas).

---

## 8. Sources

- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) `[OFFICIAL]`
- [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`
- [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) `[OFFICIAL]`
- [MCP in Claude Code](https://docs.claude.com/en/docs/claude-code/mcp) `[OFFICIAL]`
