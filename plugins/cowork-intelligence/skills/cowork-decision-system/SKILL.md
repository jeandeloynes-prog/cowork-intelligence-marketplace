---
name: cowork-decision-system
description: Arbres de décision pour Claude Code / Cowork — quand utiliser un skill / une command / un subagent / un hook / un MCP ; quand passer en multi-agent ; quand activer le prompt caching ; quand splitter un skill ; quand introduire de la mémoire externe ; matrice comparative agentique ; taxonomie des compétences. Déclencheurs — "quel pattern choisir", "skill ou command", "mono ou multi-agent", "quand utiliser MCP", "arbre de décision agentique", "comparatif framework agent", "skill compétences", "taxonomie", "que recommandes-tu".
allowed-tools: Read, Grep, WebFetch
---

# Decision System

> **Goal.** Replace guesswork with arbitrated decision trees. Each tree is grounded in evidence from the other skills in this plugin.

---

## 1. Extension-point selection

```
Need to extend Claude's behavior?
│
├── Should Claude apply this AUTOMATICALLY when context matches?
│   ├── Yes → SKILL (write a precise description)
│   └── No
│       │
│       ├── Does the USER want a reusable prompt they type?
│       │   └── Yes → SLASH COMMAND
│       │
│       ├── Does the work need a FRESH context window + a small summary back?
│       │   └── Yes → SUBAGENT
│       │
│       ├── Is it a SIDE EFFECT tied to a specific runtime event?
│       │   └── Yes → HOOK
│       │
│       ├── Does it provide TOOLS / RESOURCES / live state from outside?
│       │   └── Yes → MCP SERVER
│       │
│       └── Is it a persistent rule / context for the project?
│           └── Yes → CLAUDE.md
```

Use this tree at the *design* moment. If you've already started writing the wrong shape, the audit engine will catch it later.

---

## 2. Mono- vs multi-agent

```
Is the task naturally parallel (multiple independent sub-problems)?
├── No → SINGLE AGENT
└── Yes
    │
    ├── Does each sub-problem need a CLEAN context (no shared scratch)?
    │   ├── No → SINGLE AGENT with parallel tool calls
    │   └── Yes
    │       │
    │       ├── Is the quality lift worth ~15× token cost?
    │       │   ├── No → SINGLE AGENT
    │       │   └── Yes → MULTI-AGENT (orchestrator + sub-agents)
```

Cost reference: [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]` — "multi-agent systems use about 15× more tokens than chats."

---

## 3. When to enable prompt caching

```
Do you control the API call (Agent SDK / custom harness)?
├── No → caching is harness-managed; focus on stable prefixes
└── Yes
    │
    ├── Is the cached prefix ≥ 1024 tokens (Sonnet/Opus) or 2048 (Haiku)?
    │   ├── No → not cacheable
    │   └── Yes
    │       │
    │       ├── Will the session run > 5 minutes with that prefix stable?
    │       │   ├── No → not worth the write cost
    │       │   └── Yes
    │       │       │
    │       │       ├── Will it stay stable > 1 hour?
    │       │       │   ├── No → use 5-min TTL (1.25× write, 0.1× read)
    │       │       │   └── Yes → use 1-hour TTL (2× write, 0.1× read)
```

Source: [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) `[OFFICIAL]`.

---

## 4. When to split a skill

```
Is SKILL.md body > 20 KB?
├── Yes → SPLIT (move depth to references/)
└── No
    │
    ├── Is body > 8 KB AND skill loads on > 30 % of turns?
    │   ├── Yes → SPLIT (hot skill; trim it)
    │   └── No
    │       │
    │       ├── Does the skill cover > 1 conceptually distinct domain?
    │       │   ├── Yes → SPLIT (one skill per domain)
    │       │   └── No → keep
```

---

## 5. When to introduce external memory

```
Does the agent need to RECALL across sessions?
├── No → in-context is fine
└── Yes
    │
    ├── Is the recall pattern "find similar past notes"?
    │   ├── Yes → VECTOR memory (pgvector / Qdrant / Weaviate)
    │   └── No
    │       │
    │       ├── Are there entities + relationships to traverse?
    │       │   ├── Yes → GRAPH memory (Graphiti / Neo4j)
    │       │   └── No
    │       │       │
    │       │       ├── Just want persistent notes the model can read/write?
    │       │       │   ├── Yes → Anthropic memory tool OR plain files
    │       │       │   └── No → reconsider whether you really need memory
```

---

## 6. Comparative matrix — agentic architectures

| Architecture | Token cost | Latency | Quality lift | Best for |
|---|---|---|---|---|
| Single agent (no skills) | 1× | Low | Baseline | Trivial tasks |
| Single agent + skills | ~1.2× | Low | + | Most real work |
| Workflow (chained prompts) | n× | High (serial) | + on structure | Pipelines with known shape |
| Routing | 1.1× | Low | + on clarity | Heterogeneous input |
| Parallelization | k× | Low (concurrent) | + on coverage | Independent sub-tasks |
| Orchestrator-workers | 5–15× | Medium | ++ on open-ended | Research, exploration |
| Evaluator-optimizer | 2× per cycle | High | ++ on quality | Writing, code review |
| Pure agent (loop) | unbounded | unbounded | depends | Unknown path, capable tools |

Source for cost orders: [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]` and [Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents) `[OFFICIAL]`.

---

## 7. Taxonomy — what to learn, in order

Five levels, mapped to roles you might hire or grow into.

### L1 — User
Knows what Claude Code / Cowork is. Can install a plugin. Writes a `CLAUDE.md`.

### L2 — Power user
Writes their own slash commands. Adds a small skill. Configures one MCP server. Knows the difference between skill, command, subagent, hook, MCP.

### L3 — Plugin author
Ships a multi-skill plugin with consistent descriptions. Versions it. Writes hooks that don't cost the user latency. Understands token cost of each piece. Can audit someone else's setup with help.

### L4 — Agentic architect
Designs orchestration (routing, parallelization, sub-agents) by trade-off, not by fashion. Picks the right memory backend for the access pattern. Reasons in token budgets. Instruments observability with OTel GenAI. Knows when **not** to multi-agent.

### L5 — Distinguished
Defines org-wide standards (skill conventions, CLAUDE.md tiers, MCP catalog, eval suites). Owns drift prevention. Mentors L3/L4. Contributes upstream to MCP / Claude Agent SDK / OTel SemConv.

### Anti-skills to unlearn
- **Cargo-cult multi-agent.** Reaching for orchestrator-workers because it sounds sophisticated.
- **Premature skill explosion.** Splitting a 200-line skill into 12 micro-skills before measuring.
- **DRY-everywhere on prompts.** Some duplication makes prompts more reliable than mutualization.
- **Over-engineered MCPs.** A bash script the user runs is usually cheaper.
- **CLAUDE.md as scratchpad.** It costs tokens every turn. Use external notes for transient state.

---

## 8. "What should I do next?" — short prompts the user can copy

| Situation | First move |
|---|---|
| "Claude is slow / expensive" | Run `/cowork-optimize` — start with MCP and skill body sizes. |
| "Skills don't trigger reliably" | Run `/cowork-analyze` — likely description weakness or collision. |
| "I want to build a new plugin" | Start from `cowork-foundations` and `cowork-skills-hooks-mcp` skills. |
| "We're hitting context-window limits frequently" | Read `cowork-context-token-optimization`; then audit CLAUDE.md + MCP. |
| "I want subagents" | Read the orchestration skill first; quantify whether the lift justifies ~15× tokens. |
| "Production agent misbehaved" | Read `cowork-observability-governance`; you probably lack tracing. |

---

## 9. Sources

- [Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents) `[OFFICIAL]`
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]`
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) `[OFFICIAL]`
- [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) `[OFFICIAL]`
- [Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) `[OFFICIAL]`
