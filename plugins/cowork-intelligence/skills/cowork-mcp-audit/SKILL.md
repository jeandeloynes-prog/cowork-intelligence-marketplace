---
name: cowork-mcp-audit
description: Audit dédié aux MCP servers — énumère les serveurs déclarés par tous les plugins, mesure la taille des fichiers .mcp.json, identifie les serveurs probablement les plus coûteux en tokens (sans pouvoir mesurer leurs descriptions de tools depuis le sandbox). Déclencheurs — "audit MCP", "coût MCP", "MCP trop bavard", "MCP tools count", "trop de MCP servers", "MCP audit", "mesurer MCP", "lister MCP servers".
allowed-tools: Read, Grep, Glob, Bash
---

# MCP Audit Skill

> **Goal.** Quantify the MCP server footprint of a Claude Code / Cowork setup as far as static analysis allows, and emit a prioritized report.
>
> **Honest scope.** The true per-turn cost of MCP servers comes from their live tool descriptions and schemas, which are only known at runtime when the server is launched. From a static scan we can measure:
> - which servers are declared (and where)
> - the size of their `.mcp.json` declarations
> - any documentation or schema files shipped alongside the server
>
> What we CANNOT statically measure: the exact tool count and schema bytes the server returns on `tools/list`. We can estimate from package metadata and conservative assumptions, but the only exact source is a live MCP handshake — which the user can run via the companion bash script.

---

## 1. Static inventory

Scan these paths (skip silently if missing):

| Source | Path |
|---|---|
| User-global MCP | `~/.claude/.mcp.json` |
| Project-scoped MCP | `./.mcp.json`, `./.claude/.mcp.json` |
| Plugin-declared MCP | `~/.claude/plugins/cache/*/*/*/plugin.json` (field `mcpServers`), `~/.claude/plugins/cache/*/*/*/.mcp.json` |
| Settings-level MCP | `~/.claude/settings.json` (field `enabledMcpJsonServers` if present) |

For each server, capture:
- Marketplace + plugin of origin (or "user" / "project")
- Command + args (redact env values)
- Size of the declaration file
- Existence of `tools.json` / `manifest.json` / `README.md` next to it

---

## 2. Estimate cost — conservative model

The exact tool description cost is unknown without a live handshake. Estimate using:

```
Per-server stable cost ≈ (n_tools × avg_description_length)
                        + (n_tools × avg_schema_bytes)
                        + (system message bytes from server, if any)
```

Default assumptions (calibrated on public MCP servers):
- `avg_description_length ≈ 200 chars` per tool
- `avg_schema_bytes ≈ 400 chars` per tool (JSON Schema for inputs)
- `n_tools` : if you have access to the server package, count from its source; otherwise use a placeholder of 5 with a `?` flag.

So a typical server with 10 tools costs ≈ 6 000 chars ≈ 1 500 tokens *per turn*. With 53 servers (as observed in this user's setup), even a conservative average of 5 tools per server gives roughly:

```
53 × 5 × 600 = 159 000 chars ≈ 40 000 tokens per turn
```

This is the **upper end** estimate. The real number depends entirely on each server's design.

---

## 3. Live measurement — when accuracy matters

To get the real cost, you need to interrogate each MCP server. There is no harness-side accessor for that, but you can spawn each server manually and send a `tools/list` JSON-RPC request over stdin. The plugin ships a helper:

```
bash $CLAUDE_PLUGIN_ROOT/scripts/probe_mcp_server.sh <command> [args...]
```

Behavior:
1. Spawns the command as a subprocess with `stdio` transport.
2. Sends `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}` then `{"jsonrpc":"2.0","id":2,"method":"tools/list"}`.
3. Reads the responses, counts tools, sums their description and schema bytes.
4. Prints a one-line summary: `<server> tools=N description_bytes=B schema_bytes=B total≈T tokens`.

Limitations:
- Some servers require env vars or auth tokens to start. Without them they may error out — the script reports the failure but doesn't fake numbers.
- HTTP / SSE / Streamable HTTP transports are not probed by the v0.2.0 helper (stdio only). Coverage to be extended.
- Probing can be slow if the server has heavy startup (think Docker images).

---

## 4. Report shape

```markdown
# MCP Audit — <date>

## Inventory
| Marketplace | Plugin | Server | Transport | Tools (est/measured) | Cost estimate |
|---|---|---|---|---|---|
| claude-for-legal | commercial-legal | ... | stdio | 5 (?) | ~1 500 tokens |
| claude-plugins-official | atlassian | atlassian | stdio | 12 (measured) | ~3 600 tokens |

## High-cost servers (>2 500 tokens estimated)
- ...

## Servers with no schema (HIGH risk of agent retries)
- ...

## Recommendations
1. Disable <X> via /plugin disable — saves ~Y tokens/turn.
2. Probe <Z> live to confirm cost.
```

---

## 5. Decision: what to do with the report

After the report, the user usually wants:
- **Disable expensive unused servers** : `/plugin disable <plugin>@<marketplace>` then `/reload-plugins`.
- **Pin specific servers** : keep them in `~/.claude/.mcp.json` for global use, remove from individual plugins to avoid duplication.
- **Audit a specific noisy server's tool list** : run `probe_mcp_server.sh` and inspect.

---

## 6. Sources

- [MCP specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25) `[OFFICIAL]`
- [MCP transports spec](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) `[OFFICIAL]`
- [MCP in Claude Code](https://docs.claude.com/en/docs/claude-code/mcp) `[OFFICIAL]`
- [Anthropic — Advanced tool use (Tool Search Tool)](https://www.anthropic.com/engineering/advanced-tool-use) `[OFFICIAL]`
