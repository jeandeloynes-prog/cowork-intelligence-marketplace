---
name: cowork-observability-governance
description: Observabilité agentique et gouvernance — OpenTelemetry GenAI semantic conventions, métriques (tokens, latency, tool calls, error rate), plateformes (Langfuse, LangSmith, Arize Phoenix, Datadog LLM Obs, Braintrust), tracing distribué, prompt debugging, versionnement skills/prompts, drift prevention, lifecycle, changelog, équipe. Déclencheurs — "observabilité agent", "tracing LLM", "Langfuse", "LangSmith", "Arize Phoenix", "OpenTelemetry GenAI", "métrique agent", "gouvernance IA", "skill versioning", "prompt lifecycle", "drift", "audit AI", "monitoring LLM".
allowed-tools: Read, Grep, WebFetch
---

# Observability & Governance for Agentic Systems

> **Goal.** Treat your Claude Code / Cowork deployment as a production system: measurable, versioned, auditable, and recoverable.

---

## 1. The minimum viable observability stack

You need answers to four questions, in order:

1. **What did the agent do?** — traces with tool calls and outputs.
2. **What did it cost?** — token counts in/out/cached, plus dollars.
3. **How long did it take?** — latency, TTFT (time to first token), per-step duration.
4. **Was it right?** — quality signals (user feedback, LLM-as-judge, deterministic tests).

If you can't answer all four, fix that gap before tuning anything else.

---

## 2. OpenTelemetry GenAI Semantic Conventions

Source: [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) `[OFFICIAL — OpenTelemetry project]`.

- Maintained by the **GenAI SIG**, active since April 2024.
- **Status: experimental** at time of writing — API not yet stabilized. Verify status before relying on attribute names in a production schema.
- Defines spans, events, exceptions, and metrics for LLM operations.

Named metrics include:
- `gen_ai.client.token.usage`
- `gen_ai.client.operation.duration`
- `gen_ai.client.operation.time_to_first_chunk`
- `gen_ai.client.operation.time_per_output_chunk`

A dedicated [MCP semantic convention](https://opentelemetry.io/docs/specs/semconv/gen-ai/mcp/) is also published, covering MCP-specific spans.

Practical adoption path:
1. Emit OTel traces from your harness (Anthropic SDK, Agent SDK, or wrapper).
2. Ship them to any backend that speaks OTLP (Honeycomb, Datadog, Grafana Tempo, Phoenix, etc.).
3. Standardize attribute names so dashboards survive backend swaps.

---

## 3. Platforms — verified status

| Platform | Position | Notable note |
|---|---|---|
| **Langfuse** | Framework-agnostic, OSS, self-hostable | Active, broad adoption |
| **LangSmith** | LangChain-first, closed-source, seat-based pricing | First-party for LangChain / LangGraph |
| **Arize Phoenix** | OSS, evaluator-heavy | Strong eval and LLM-as-judge tooling |
| **Datadog LLM Observability** | Datadog-native | Easiest if you already use Datadog |
| **Braintrust** | Eval-centric | Strong dataset + evaluation flow |
| **Honeycomb LLM Observability** | OTel-native | Good if you already use Honeycomb |
| **Helicone** | LLM proxy (changes base URL) | **Acquired by Mintlify on 3 March 2026; in maintenance mode** — new projects: avoid. Source: [Mintlify acquires Helicone](https://www.mintlify.com/blog/mintlify-acquires-helicone). |

**Selection rule.** If you already run an observability backend (Datadog / Grafana / Honeycomb), extend it via OTel GenAI conventions. Otherwise, Langfuse or Phoenix give the fastest standalone setup.

---

## 4. What to instrument first

A minimum-overhead instrumentation list for a Claude Code / Cowork-style deployment:

| Signal | Why | Where to capture |
|---|---|---|
| Input tokens / output tokens / cached tokens | Cost control, prompt-caching ROI | Per LLM call |
| Tool name, args hash, duration, exit code | Tool-thrash detection, error pattern hunting | `PostToolUse` hook |
| Skill load events (which, when) | Detect skills that load but never get used | `SessionStart` + custom log |
| MCP server, tool, latency, byte size | Spot noisy or slow MCP servers | MCP client wrapper |
| Subagent dispatch + return summary size | Validate that subagents actually save context | Subagent return path |
| Session duration, turn count, compaction events | Capacity planning | Session-level |
| User satisfaction signal (thumbs / corrections) | Quality drift detection | UI or post-session prompt |

Capture **early**. Adding observability after a regression is too late.

---

## 5. Governance — what to version, what to log, what to gate

### 5.1 Version everything that ships into the model's context
- **Skills**: file path is the identifier; commit to git; every behavioral change = a commit message that explains *why*.
- **CLAUDE.md**: ditto.
- **MCP server configs (`.mcp.json`)**: in git, with the same code review as application code.
- **Hooks**: in git; their scripts get the same security review as deploy scripts.
- **Plugin `plugin.json`**: bump `version` (semver) on any behavioral change.

### 5.2 Maintain a CHANGELOG per plugin
At minimum:
```
## 0.2.0 — 2026-05-10
- Added: cowork-decision-engine skill
- Changed: token-optimization skill description (added "context rot" trigger)
- Removed: legacy hooks/audit-log.sh (replaced by OTel exporter)
```
A `CHANGELOG.md` per plugin is the single most useful gov artifact — it lets reviewers understand *what changed for the model* over time.

### 5.3 Gate behavior changes
Before merging a skill / prompt / hook change:
- Eval set runs on the proposed change (deterministic + LLM-as-judge).
- Token-impact estimate (load the new body, count bytes).
- Conflict scan against existing skills (overlapping descriptions / triggers).

### 5.4 Drift prevention
- **Schedule a quarterly review** of all skill descriptions: do they still describe what the skill does?
- **Schedule a quarterly review** of CLAUDE.md cascades: any rule that hasn't fired in 90 days probably isn't needed.
- **Detect unused MCPs**: if a tool hasn't been called in 30 days, ask whether the server should remain enabled.

---

## 6. Failure modes worth alerting on

| Symptom | Likely cause | Where to look |
|---|---|---|
| Token bill spike with no usage spike | New verbose skill or MCP loaded | Recent commits to `skills/` or `.mcp.json` |
| Latency p95 doubles | Slow synchronous hook | `PreToolUse` hook scripts |
| Tool error rate climbs | External API regression or bad schema | Tool span errors |
| Subagent dispatches doubled with no quality lift | Orchestrator hallucination | Compare task type vs subagent count |
| Same skill loaded every turn | Description over-broad | Tighten description, add an exclusion |
| Compaction events frequent | Context bloat — skills / tool outputs too large | Find the heaviest contributor |

---

## 7. Skills, hooks, MCPs — what NOT to log

- **Secrets passed as tool args**: redact env vars before persisting.
- **Full user prompts** if your domain is regulated (medical, legal, financial): hash or summarize.
- **Full tool outputs by default**: log size + first/last lines; expand on demand.

OTel GenAI conventions explicitly distinguish content (input/output text) from metadata (counts, IDs, names) for this reason.

---

## 8. Honest gaps

- **OTel GenAI SemConv stability**: experimental at time of research. Attribute names may rename before stable release.
- **Anthropic-native observability surface**: no dedicated dashboard or first-party export endpoint documented at time of writing beyond raw API responses.
- **Cross-platform eval framework consensus**: there isn't one. Langfuse, LangSmith, Phoenix, Braintrust each have their own eval primitives.

---

## 9. Sources

- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) `[OFFICIAL]`
- [OpenTelemetry GenAI metrics](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-metrics/) `[OFFICIAL]`
- [OpenTelemetry MCP semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/mcp/) `[OFFICIAL]`
- [Langfuse](https://langfuse.com/)
- [LangSmith](https://smith.langchain.com/)
- [Arize Phoenix](https://phoenix.arize.com/)
- [Mintlify acquires Helicone](https://www.mintlify.com/blog/mintlify-acquires-helicone)
- [Helicone joining Mintlify](https://www.helicone.ai/blog/joining-mintlify)
