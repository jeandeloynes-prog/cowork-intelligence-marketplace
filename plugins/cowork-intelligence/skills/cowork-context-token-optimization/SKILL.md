---
name: cowork-context-token-optimization
description: Optimisation contexte et tokens pour Claude Code / Cowork — prompt caching (tarifs, TTL, 4 breakpoints), context rot, compaction, structured note-taking, sub-agent context isolation, token-efficient tool use, dimensionnement skills / CLAUDE.md / MCP, mesure de coût réel. Déclencheurs — "réduire les tokens", "coût Claude trop élevé", "context window plein", "compaction", "prompt caching", "context rot", "context engineering", "skill trop gros", "MCP coûte cher", "économiser tokens", "token budget", "skill cache".
allowed-tools: Read, Grep, Glob, Bash, WebFetch
---

# Context & Token Optimization

> **Goal.** Cut token cost without hurting quality. Every recommendation is grounded in Anthropic primary docs or in measurable runtime behavior. No magical compression promises.

---

## 1. What actually consumes tokens

On every turn, the prompt Claude sees is approximately:

```
[harness system prompt]
  + [every available skill DESCRIPTION] (small but per-skill)
  + [every available MCP tool DESCRIPTION + schema] (often large)
  + [every loaded skill BODY] (sticky for the rest of the turn)
  + [CLAUDE.md cascade]
  + [conversation so far, including all tool inputs and outputs]
  + [current user message]
```

Three properties matter for cost engineering:

1. **Stable prefixes can be cached** (prompt caching) — pay once, reuse cheap.
2. **Sticky payloads stay** for the rest of the turn — loading a 5 KB skill body costs that on every subsequent message in the same context.
3. **Tool outputs dominate** in long agentic loops — bigger than any skill.

---

## 2. Prompt caching (Anthropic API)

Source: [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) `[OFFICIAL]` (URL is the current `platform.claude.com` location; the older `docs.anthropic.com` URL also redirects there).

### 2.1 Pricing relative to base input price

| Operation | Multiplier |
|---|---|
| Cache write — 5-min TTL | **1.25 ×** input |
| Cache write — 1-hour TTL | **2 ×** input |
| Cache read | **0.1 ×** input |

> **Verification note.** These multipliers were cross-checked against multiple secondary sources citing Anthropic docs. Re-verify on the live pricing page before quoting in a contract.

### 2.2 Constraints to design around

- **Minimum cacheable size**: 1 024 tokens for Sonnet / Opus class models; 2 048 tokens for Haiku class `[OFFICIAL — verify on live doc]`. Below this: no cache, no error.
- **Maximum 4 cache breakpoints** per request via `cache_control: {"type": "ephemeral"}`.
- **Order matters**: `tools` → `system` → `messages`. Place a breakpoint after the most stable prefix.
- **1-hour entries must appear before 5-minute entries** when mixing TTLs.

### 2.3 Practical pattern

If you control the API call (Agent SDK or custom harness):

```python
# Put rarely-changing content first, mark the breakpoint after it
system_blocks = [
    { "type": "text", "text": HUGE_SKILL_LIBRARY_TEXT,
      "cache_control": {"type": "ephemeral"} },
    { "type": "text", "text": session_specific_context }
]
```

If you use Claude Code as-is: prompt caching is handled by the harness; you optimize by **keeping the early-in-context content stable** (don't reshuffle skills, don't regenerate CLAUDE.md mid-session).

---

## 3. Context engineering — the three Anthropic-blessed moves

Source: [Effective context engineering for AI agents (29 Sept 2025)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) `[OFFICIAL]`.

Two core concepts from the article:

- **Context engineering** = "curating and maintaining the optimal set of tokens during LLM inference".
- **Context rot** = "as the number of tokens in the context window increases, the model's ability to accurately recall information from that context decreases".

The article names three techniques to manage long-running context:

### 3.1 Compaction
Periodic summarization to drop stale exchanges. Claude Code triggers compaction automatically when approaching the window limit. Lighter-weight: clear tool results (especially long ones) once consumed.

### 3.2 Structured note-taking
Write durable facts to disk (`./notes/`, project memory, CLAUDE.md mid-session edits). Recall them by reading the file when needed. The agent's working memory stays small.

### 3.3 Sub-agent architectures
Each subagent has its own context window and returns a *compact summary*. The orchestrator never sees the subagent's full reasoning. Cost: more total tokens; benefit: better quality per top-level token.

Direct quote from [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]`:

> "Agents use 4× more tokens than chat interactions and multi-agent systems use about 15× more tokens than chats."

**Implication.** Multi-agent only pays off when the task quality matters more than the token bill. For routine work, single-agent + good skills is cheaper *and* faster.

---

## 4. Token-efficient tool use

Source: [Token-efficient tool use](https://docs.claude.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use) `[OFFICIAL]`.

- Beta header (when applicable): `token-efficient-tools-2025-02-19`.
- **Only for Claude 3.7 Sonnet.** Claude 4-class models have this **built in** — do NOT set the header.
- Reported reduction: up to 70 % on output tokens (14 % average for early users) — figures cited on the doc page.

### "Advanced tool use" capabilities (Anthropic engineering, late 2025)

Source: [Advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use) `[OFFICIAL]`.

- **Tool Search Tool** — discover tools dynamically instead of loading all schemas every turn. Big win when you have many MCP servers.
- **Programmatic Tool Calling** — Claude writes code that orchestrates multiple tools without intermediate results filling the context.
- **Tool Use Examples** — few-shot examples shipped with each tool for correctness.
- **Fine-grained tool streaming** — stream parameters without full-JSON buffering. Available on Sonnet 4.5, Haiku 4.5, Sonnet 4, Opus 4.

The exact beta header name varies — re-verify on the doc page before integration.

---

## 5. Skill and MCP sizing rules

| Item | Rough budget |
|---|---|
| Single SKILL.md body | Aim < 5 KB (~ 1 250 tokens) for hot skills, < 20 KB for rare ones |
| Single skill description | < 600 characters; load-bearing keywords up front |
| CLAUDE.md (per file) | < 4 KB ideally; if bigger, split via `@import` or move into a skill |
| MCP server tool count | 3–10 is comfortable; 30+ requires Tool Search |
| MCP tool description | 1–3 sentences plus 1 schema; no changelogs, no marketing |
| Hook command output | < 5 lines; use `suppressOutput` for the rest |

These are heuristics calibrated on community plugins and not Anthropic-mandated.

---

## 6. Measure before you optimize

The first move on any "Claude is expensive" investigation is to **count**. Without numbers you can't tell whether the problem is skills, MCPs, CLAUDE.md, or tool output.

A minimal Bash-only measurement script (drop in `scripts/`):

```bash
#!/usr/bin/env bash
# Estimate token-equivalent bytes for everything Claude Code loads.
# Rough rule: 1 token ≈ 4 bytes English text.
# Run from the project root.

set -euo pipefail

count() { wc -c < "$1" 2>/dev/null || echo 0; }

echo "=== CLAUDE.md cascade ==="
for f in ~/.claude/CLAUDE.md ./CLAUDE.md ./.claude/CLAUDE.md; do
  [ -f "$f" ] && printf "  %s %s bytes\n" "$f" "$(count "$f")"
done

echo "=== Skills (project) ==="
find .claude/skills -name SKILL.md 2>/dev/null | while read -r f; do
  printf "  %s %s bytes\n" "$f" "$(count "$f")"
done

echo "=== MCP servers (project) ==="
[ -f .mcp.json ] && cat .mcp.json | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print('  servers:', list(d.get('mcpServers', {}).keys()))"
```

This won't give exact tokens, but it surfaces the offenders. For exact counts, use the Anthropic `count_tokens` API endpoint or `tiktoken`-style libraries (not exact for Claude but close enough for ordering).

---

## 7. Anti-patterns to delete on sight

- **A skill that restates CLAUDE.md.** Duplication doubles cost for no signal gain.
- **A CLAUDE.md that pastes a README.** Either prune the README or `@import` only the relevant section.
- **An MCP that returns a 50 KB JSON when 200 tokens would do.** Add a `summary=true` parameter.
- **A skill that includes "use this skill when..." in the body.** That's the description's job.
- **Verbose hooks adding turn-by-turn context.** Each line costs forever.
- **Loading both a "general" skill and 5 "specific" skills that overlap.** Pick one layer.
- **Sub-agent dispatch for trivial work.** ~15× cost — only worth it for parallelism or context isolation.

---

## 8. When optimization stops paying

Once you've:
1. Removed dead skills and dead MCP tools,
2. Tightened descriptions,
3. Sized CLAUDE.md under 4 KB per file,
4. Enabled prompt caching for stable prefixes,
5. Switched to summary modes on noisy tools,

further compression usually trades quality for tokens. Stop. Spend your effort on better routing (right skill, right model, right subagent) instead.

---

## 9. Sources

- [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) `[OFFICIAL]`
- [Token-efficient tool use](https://docs.claude.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use) `[OFFICIAL]`
- [Advanced tool use (engineering blog)](https://www.anthropic.com/engineering/advanced-tool-use) `[OFFICIAL]`
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) `[OFFICIAL]`
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]`
- [Token-saving updates](https://www.anthropic.com/news/token-saving-updates) `[OFFICIAL]`
