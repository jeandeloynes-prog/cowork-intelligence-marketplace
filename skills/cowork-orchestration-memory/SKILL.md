---
name: cowork-orchestration-memory
description: Orchestration agentique et systèmes de mémoire — patterns Anthropic (prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer), mono vs multi-agent, sub-agent context isolation, memory tool, vector vs graph memory (pgvector, Graphiti, Letta), Claude Agent SDK, comparatif frameworks (LangGraph, CrewAI, Microsoft Agent Framework, DSPy). Déclencheurs — "multi-agent", "orchestration", "subagent", "agent SDK", "Claude Agent SDK", "agent pattern", "memory agent", "vector memory", "graph memory", "Letta", "MemGPT", "Graphiti", "LangGraph", "CrewAI", "AutoGen", "agent workflow", "router agent".
allowed-tools: Read, Grep, WebFetch
---

# Agent Orchestration & Memory

> **Goal.** Choose the right orchestration shape and memory backend for your agentic workload, with grounding in Anthropic's own pattern catalogue and verified framework status.

---

## 1. Anthropic's pattern catalogue

Source: [Building Effective AI Agents (Anthropic Research, Dec 2024)](https://www.anthropic.com/research/building-effective-agents) `[OFFICIAL]`.

The article distinguishes **workflows** (LLM-orchestrated by predefined code paths) from **agents** (LLM-driven tool use in a loop). It catalogs five workflow patterns plus the agent pattern.

### 1.1 Prompt chaining
Sequence of steps. Output of step *n* feeds prompt of step *n+1*. Add gates between steps for validation.
- *Use when*: the task decomposes cleanly into ordered subtasks.
- *Cost*: linear in steps.
- *Failure mode*: errors compound; budget for retries.

### 1.2 Routing
A classifier LLM dispatches to specialized handlers.
- *Use when*: inputs cluster into clearly distinct types (e.g. refund vs technical support vs sales).
- *Cost*: one extra LLM call per request.
- *Failure mode*: misclassification at the router silently degrades downstream quality. Log routing decisions.

### 1.3 Parallelization
Run multiple LLM calls concurrently and aggregate. Two sub-patterns:
- **Sectioning**: split the task; each call handles a piece.
- **Voting / ensembling**: same task to several callers; aggregate via vote or judge.
- *Cost*: parallel × per-call cost; latency = max(call durations).
- *Failure mode*: prompt drift between parallel calls; pin the same prompt template.

### 1.4 Orchestrator-workers
A central LLM dynamically decomposes the task and delegates to worker LLMs, then synthesizes.
- *Use when*: subtasks aren't known upfront (e.g. open-ended research).
- *Cost*: orchestrator + workers. Anthropic reports their multi-agent research system uses **~15× the tokens of a single chat** ([source](https://www.anthropic.com/engineering/multi-agent-research-system)) `[OFFICIAL]`.
- *Failure mode*: orchestrator hallucinates work; workers reinvent each other's results. Pass a shared scratchpad.

### 1.5 Evaluator-optimizer
One LLM produces, another evaluates and gives feedback. Iterate.
- *Use when*: quality matters more than latency (writing, code review, structured output).
- *Cost*: 2× per cycle, plus cycle count.
- *Failure mode*: critic gets stuck on cosmetic issues; bound iterations.

### 1.6 Agent (autonomous loop)
LLM uses tools in a loop until termination criteria are met.
- *Use when*: the path is unknown and tool use is the right substrate.
- *Cost*: hardest to bound; budget per loop iteration.
- *Failure mode*: infinite loops, tool thrashing. Add step limits, tool quotas, escalation gates.

### Anthropic's headline guidance
> "The most successful implementations weren't using complex frameworks or specialized libraries, but instead were building with simple, composable patterns."

Translation: prefer the smallest pattern that fits. Don't reach for orchestrator-workers when routing would do.

---

## 2. Mono vs multi-agent — the honest trade-off

| Dimension | Single agent + skills | Multi-agent / subagents |
|---|---|---|
| Token cost | 1× | ~4× (agents vs chat) to ~15× (multi-agent) |
| Latency | Lower (no fan-out) | Higher (synchronization) |
| Context isolation | Poor (everything shared) | Strong (each subagent has its own window) |
| Failure surface | One model, easier to debug | Coordination bugs, partial failures |
| Best for | Most coding tasks, single-domain work | Research, parallel exploration, multi-domain synthesis |

Source for the cost multipliers: [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]`.

**Rule of thumb.** Use multi-agent only when *(a)* the work parallelizes naturally, *(b)* each subagent benefits from a clean context, *and (c)* the quality lift justifies the bill. If only one of these is true, single-agent with well-designed skills is usually better.

---

## 3. Claude Agent SDK — what you should know in 2026

Source: [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) and [Migration guide](https://platform.claude.com/docs/en/agent-sdk/migration-guide) `[OFFICIAL]`.

- **Renamed from "Claude Code SDK" on 29 September 2025**, alongside Claude Sonnet 4.5.
- Python package: `claude-agent-sdk` (was `claude-code-sdk`).
- TypeScript package: `@anthropic-ai/claude-agent-sdk`.
- Migration: rename import (`claude_code_sdk` → `claude_agent_sdk`), rename options class (`ClaudeCodeOptions` → `ClaudeAgentOptions`).
- The SDK exposes the same harness pieces (skills, hooks, MCP, subagents) as Claude Code's CLI, programmatically.
- **CLAUDE.md is not loaded by default**: set `settingSources: ['project']` (TS) or `setting_sources=["project"]` (Python).

When to choose Claude Agent SDK over a third-party framework:
- You're already on Claude and want first-class Skills / Hooks / MCP integration.
- You want subagent context isolation without writing your own.
- You don't need cross-provider routing.

When to look elsewhere:
- Cross-LLM-vendor abstraction (Microsoft Agent Framework, LangGraph).
- Graph-based control flow with checkpointing and human-in-the-loop replay (LangGraph).
- Role/crew metaphor with built-in delegation (CrewAI).

---

## 4. Third-party orchestration frameworks — verified status (May 2026)

| Framework | Doc URL | Paradigm | Status note |
|---|---|---|---|
| **LangGraph** | [docs.langchain.com/oss/python/langgraph](https://docs.langchain.com/oss/python/langgraph/overview) | Graph (nodes = computation, edges = control flow), shared state, checkpoints, HITL | 1.0 stable Oct 2025 (per LangChain docs); active development |
| **CrewAI** | [docs.crewai.com](https://docs.crewai.com/en/concepts/agents) | Role-based "crews" (role + goal + backstory), processes (sequential / hierarchical / consensual) | Active; MCP and A2A support per docs |
| **Microsoft Agent Framework** | [learn.microsoft.com/en-us/agent-framework/overview](https://learn.microsoft.com/en-us/agent-framework/overview/) | Unified .NET + Python, multi-agent, MCP/A2A interop | Public preview Oct 2025, GA Apr 2026. **Successor to AutoGen + Semantic Kernel** |
| **AutoGen** | [microsoft.github.io/autogen](https://microsoft.github.io/autogen/stable/) | Conversation-based async event-driven | **Maintenance mode** — new projects steered to Microsoft Agent Framework |
| **DSPy** | [dspy.ai](https://dspy.ai/) | Declarative, programmatic — signatures + optimizers (MIPROv2) | Active; optimizer-driven prompt compilation |
| **Claude Agent SDK** | [platform.claude.com/docs/en/agent-sdk/overview](https://platform.claude.com/docs/en/agent-sdk/overview) | LLM-in-a-loop harness with Skills / Hooks / Subagents / MCP | Active; first-class for Claude |

**Source confidence.** Framework URLs and paradigms are verified from primary docs. Specific version numbers and release dates beyond the milestones above should be re-checked on GitHub releases pages before being quoted.

---

## 5. Memory backends — choose by access pattern

Agent memory splits into three storage shapes:

### 5.1 Vector memory (semantic recall by similarity)
| Backend | Where it shines | Caveat |
|---|---|---|
| **pgvector** | You already run Postgres; HNSW since 0.5.0 | Operations cost of Postgres at vector scale |
| **Qdrant** | Filterable search, Rust-fast | Smaller ecosystem than Postgres |
| **Weaviate** | Hybrid search (BM25 + vector) baked in | Heavier deployment |
| **Pinecone** | Managed, mature ANN | Closed-source, vendor lock |

Use vector memory when "find me past notes that are semantically similar to this query" is the dominant access pattern.

### 5.2 Graph memory (relational recall, episodes, entities)
| Backend | Where it shines | Caveat |
|---|---|---|
| **Neo4j Agent Memory** (Neo4j Labs) | Three layers (conversational / knowledge graph / reasoning); Neo4j stack | Neo4j licensing for Enterprise features |
| **Graphiti** (Zep) | Temporal bi-temporal model (validity intervals), hybrid semantic + BM25 + graph traversal | Active project; production maturity evolving |
| **MemGPT / Letta** | Multi-tier memory (context + recall + archival); now under [Letta](https://docs.letta.com/) | Project renamed and restructured; verify version |

Use graph memory when "what did entity X do in episode Y" or "what connects A to B" matters more than similarity.

### 5.3 Anthropic memory tool (beta)
Source: [Memory tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool) `[OFFICIAL]`.
- Launched in **beta on 29 September 2025**.
- Beta header: `context-management-2025-06-27`.
- Model: Claude sees a filesystem-like memory. You implement the backend (subclass `BetaAbstractMemoryTool` in Python or `betaMemoryTool` in TS). Anthropic does **not** host the memory.
- Sensible default for "give my agent persistent notes I control" without standing up a vector DB.

### 5.4 Choosing
- Need **semantic recall over notes** → vector memory.
- Need **structured facts and relationships** → graph memory.
- Need **simple persistent scratchpad you control end-to-end** → Anthropic memory tool or just files on disk.
- Need **all three** → most teams end up with vector + structured files; graph is a niche win.

---

## 6. Honest gaps

- **Exact LangGraph / CrewAI / DSPy releases for May 2026**: not re-verified during research; the framework comparison table reflects the most recent dated points found and may have been superseded by minor versions.
- **Anthropic memory tool's GA status**: still labeled beta at the cited URL during research; check before production use.
- **Best practice for combining Anthropic memory tool with external vector DBs**: no canonical Anthropic pattern published; community examples vary.

If asked for current versions or production-readiness, say "verify on the project's releases page" rather than quoting a stale number.

---

## 7. Sources

- [Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents) `[OFFICIAL]`
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) `[OFFICIAL]`
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) `[OFFICIAL]`
- [Agent SDK migration guide](https://platform.claude.com/docs/en/agent-sdk/migration-guide) `[OFFICIAL]`
- [Memory tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool) `[OFFICIAL]`
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)
- [CrewAI agents](https://docs.crewai.com/en/concepts/agents)
- [Microsoft Agent Framework overview](https://learn.microsoft.com/en-us/agent-framework/overview/)
- [DSPy](https://dspy.ai/)
- [Graphiti](https://github.com/getzep/graphiti)
- [Letta](https://docs.letta.com/)
- [Neo4j Agent Memory](https://neo4j.com/labs/agent-memory/)
