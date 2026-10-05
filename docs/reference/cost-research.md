# Cost research digest: Copilot spend, LinearB, and local tracing

**Research checked: October 5, 2026.** A colloquial digest for a team that bills Copilot only today, correlates
git/throughput in LinearB, and runs OTel + Phoenix 20.19 + Langfuse 4.50 + Grafana locally. This is not a rate card —
plan prices and credit allowances change, so check live vendor docs before quoting a number to anyone. Your Copilot
contract/enterprise terms are authoritative over anything summarized here.

## Uber's "Efficient Software Factory" post

[Uber's blog post](https://www.uber.com/us/en/blog/efficient-software-factory/) frames agentic spend as a cost
equation: `users × sessions/user × turns/session × requests/turn × tokens/request × price/token`. The first two
terms are adoption/engagement (they want these growing); the rest is where they optimize.

Metrics they say they track weekly/monthly: portfolio-level cost and spend share per tool; unit economics per tool
(cost per user, cost per 1,000 requests, tokens per request, cost per 1M tokens, cost per session, prompt-cache hit
rate); model economics (cost/requests per model, to see which model release actually moved the bill); a driver
decomposition that splits a cost change into adoption, engagement, input-workload and output-workload terms instead
of one blended number; and — importantly — **managed-agent outcomes that pair cost with a quality guardrail** (cost
per merged PR/review/alert alongside revert rate, F1, or MTTR), so a cheaper number is never read as "better" on its
own.

Levers they describe: Pareto-frontier model selection benchmarked on real PRs; defaulting subagents to a cheaper
model while the primary model handles decomposition; a token-compaction cap and a "Medium" reasoning-effort default;
prompt-cache TTL tuned to how long sessions sit idle; and routing MCP tool calls through CLI/shell resolution plus
"tool search" so large tool-schema overhead isn't resent on every turn.

**Caveat, in their own words:** "specific cost reductions we measure are unique to our environment and your mileage
may vary depending on your codebase, team size, and agent workflows." It's a vendor blog post, not a peer-reviewed
study — self-reported, not independently audited. We did not find a second public post with comparable rigor; treat
this as one well-documented data point, not an industry consensus. The reusable idea — pair a cost metric with a
quality guardrail, and decompose cost changes into named drivers — is more portable than any specific number in it.

## Copilot billing and usage: what's actually measured

- **Seats and usage are two separate meters.** Per [GitHub Copilot licenses](https://docs.github.com/en/billing/concepts/product-billing/github-copilot-licenses),
  a seat is billed per user/month; code completions and next-edit suggestions are **not** billed as usage and stay
  unlimited on paid plans. Usage-based spend for Chat, CLI, cloud agent, Spaces, Spark, and third-party coding
  agents is metered separately in **AI credits**, where the credit-to-dollar conversion is fixed but the included
  monthly allowance differs by plan — see [usage-based billing for organizations and enterprises](https://docs.github.com/en/copilot/concepts/billing-and-usage/organizations-and-enterprises/billing)
  for the current numbers rather than repeating them here, since they change with plan updates.
- Credits are pooled at the billing-entity level and reset monthly (no rollover). Budgets can be set at user,
  cost-center, org, and enterprise level, and there is **no automatic fallback to a cheaper model** when a budget is
  exhausted — access is simply blocked.
- **"Auto" is a routing feature, not one fixed model.** Per [About Copilot auto model selection](https://docs.github.com/en/copilot/concepts/models/auto-model-selection),
  Auto picks a model per task from real-time health/availability plus a task-complexity read, with optional
  Efficiency/Balance/Intelligence tiers biasing that choice. You're billed for whichever model Auto picked, with a
  flat discount on paid plans regardless of tier. GitHub doesn't publish the routing heuristics or a per-tier
  cost/quality table — "routes straightforward tasks to cheaper models" is a directional vendor claim, not an
  independently verified benchmark. **Mark this causal gap explicitly:** we have no evidence for how much of any
  observed cost change is Auto's routing versus workload mix shifting on its own.

**Unit distinction worth repeating out loud:** enterprise billing is dollars and AI credits (a GitHub-defined
conversion over token/model cost), not a raw token count. Token counts captured locally in Phoenix/Langfuse spans are
a useful *proxy signal* for correlating usage patterns over time — they won't reconcile 1:1 against the AI-credit
ledger, since GitHub's per-model credit multiplier isn't published per request.

## LinearB: throughput/git correlation vs. causal productivity

LinearB's [DORA metrics guide](https://linearb.io/blog/dora-metrics) and [AI measurement framework](https://linearb.io/blog/ai-measurement-framework)
cover the signals already in scope here: cycle-time breakdown (coding/pickup/review/deploy), deployment frequency,
change failure rate, recovery time, plus an "Adoption vs. Impact" split for AI tools (DAUs and suggestion-acceptance
on adoption; time-to-merge, merge frequency, and quality counter-metrics on impact).

LinearB's own framework explicitly argues against "lines of code" or "time saved" as primary metrics because they
don't connect usage to business value, and pairs throughput with quality counter-metrics (CFR, rework, MTTR) so
faster isn't mistaken for better. **That design is correlational, not causal:** LinearB correlates git/PR timing
signals with AI-adoption signals (seats, DAUs, acceptance rate) over the same reporting window — it does not run a
controlled experiment isolating AI assistance as the cause of a throughput change. DORA's own
[metrics guide](https://dora.dev/guides/dora-metrics/) frames these the same way: outcome indicators for comparing
delivery over time, not an attribution methodology. If AI adoption rises and cycle time drops in the same quarter,
treat that as a correlation worth investigating — headcount, codebase churn, and process changes aren't controlled
for by either tool, and no causal claim should be made to leadership without saying so.

## Local MCP options {#local-mcp-options}

**No MCP server was installed for this research — results below are discovery-only citations from primary vendor
docs and a registry search, not an installation or endorsement.**

### Phoenix (self-hosted)

Per [Phoenix MCP Servers](https://arize.com/docs/phoenix/integrations/mcp) and [Remote MCP Server](https://arize.com/docs/phoenix/integrations/remote-mcp):
a **Remote MCP Server** is built into Phoenix ≥ 19.0.0 at `/mcp` (local: `http://localhost:6006/mcp`) covering
projects, traces, sessions, datasets, experiments, prompts, and annotations — marked **beta**, tool names/behavior
may still change. A separate **Docs MCP** answers questions from Phoenix's documentation. Older servers without the
built-in endpoint can use the `@arizeai/phoenix-mcp` npm package, now in maintenance mode. Auth is OAuth
(authorization code + PKCE), with Phoenix acting as its own authorization server; tokens are scoped to the logged-in
user's permissions. Self-hosting is free with no feature gate ([Self-Hosting](https://arize.com/docs/phoenix/self-hosting)).

Per [Privacy](https://arize.com/docs/phoenix/self-hosting/security/privacy), self-hosted Phoenix sends no
trace/eval/dataset data to Arize; it does collect anonymous UI-analytics telemetry by default, opt-out via
`PHOENIX_TELEMETRY_ENABLED=false`, with full air-gap via `PHOENIX_ALLOW_EXTERNAL_RESOURCES=false`. **Current state
here, not a claim of completeness:** our image already sets `PHOENIX_PHONE_HOME_ENABLED=false`, but
`PHOENIX_TELEMETRY_ENABLED` has not yet been set explicitly — the docs-recommended toggle for UI telemetry is still
worth adding alongside it rather than assuming the phone-home variable alone covers both.

### Langfuse (self-hosted)

Per [MCP Server](https://langfuse.com/docs/api-and-data-platform/features/mcp-server): a native, authenticated,
project-scoped MCP server, reachable self-hosted at `/api/public/mcp` over `streamableHttp` with Basic Auth
(base64 `public_key:secret_key`). **Both read and write tools are available by default** — read-only requires an
allowlist configured on the MCP client yourself, it is not the out-of-the-box behavior. The canonical tool/schema
reference lives at `mcp.reference.langfuse.com`, separate from a docs-search MCP. Reverse-proxied/Kubernetes
deployments may need `LANGFUSE_MCP_ALLOWED_HOSTS` set or the host header check returns a 403.

Per [Self-host Langfuse](https://langfuse.com/self-hosting), Docker Compose is explicitly scoped to local use and
testing (single VM, no HA/scaling/backups); Kubernetes/Helm or a cloud provider path is the production-rated option.
Per [Native OpenTelemetry integration](https://langfuse.com/integrations/native/opentelemetry), the local OTLP
endpoint is `/api/public/otel` (traces at `/api/public/otel/v1/traces`); include `x-langfuse-ingestion-version: 4` or
ingested data can lag up to 10 minutes; only OTLP over HTTP (JSON/protobuf) is supported, not gRPC.

**Paid-inference caution:** Langfuse's optional LLM API/Gateway hookup (used for the in-app Playground and
LLM-as-judge evaluations) is a separate, billable call to whatever model provider you configure there — it is not
covered by "self-hosting is free," and it's distinct from the traces you ingest about your own application's model
calls.

### Grafana (local LGTM)

Already covered in [`sources.md`](sources.md): the Docker LGTM bundle is explicitly development-only. No MCP server
is documented for Grafana/LGTM as of this check — that's an open gap, not a confirmed absence.

**Shared takeaway:** both Phoenix and Langfuse keep data on your own infrastructure when self-hosted, and both gate
their MCP endpoint behind standard auth (OAuth for Phoenix, Basic Auth/API key for Langfuse) rather than leaving it
open — but neither is read-only by default, so treat either endpoint as an authenticated internal API, not a passive
dashboard, if you ever do connect a client to one.

## Agent Finder registry results

Per the skill requirement, we queried `POST https://agentfinder.github.com/api/v1/search` with
`{"query":{"text":"Phoenix Langfuse local trace analytics MCP servers"},"pageSize":5}` (two pages, 6 results total).
**Scores are Agent Finder's relevance ranking for this specific query text, not a trust, quality, or security
signal** — repeat queries returned slightly different scores/ordering, so treat these as directional. Nothing below
was installed; this is a citation of what the registry returned, nothing more.

| Registry name | Type | URL | Score |
| --- | --- | --- | --- |
| Mcp Csharp Debug | `application/ai-skill` | <https://github.com/dotnet/skills/blob/main/plugins/dotnet-ai/skills/mcp-csharp-debug/SKILL.md> | 80 |
| Mcp Server Dev | `application/vnd.anthropic.claude-plugin+json` | <https://github.com/anthropics/claude-plugins-public/blob/main/plugins/mcp-server-dev> | 75 |
| Phoenix Tracing | `application/ai-skill` | <https://github.com/github/awesome-copilot/blob/main/skills/phoenix-tracing/SKILL.md> | 70 |
| MCP CLI | `application/ai-skill` | <https://github.com/github/awesome-copilot/blob/main/skills/mcp-cli/SKILL.md> | 70 |
| Phoenix CLI | `application/ai-skill` | <https://github.com/github/awesome-copilot/blob/main/skills/phoenix-cli/SKILL.md> | 70 |
| Langsmith Trace | `application/ai-skill` | <https://github.com/langchain-ai/langsmith-skills/blob/main/config/skills/langsmith-trace/SKILL.md> | 40 |

None of these are the official Phoenix or Langfuse MCP servers — those are documented from primary vendor docs
above. The registry mostly surfaced skills that *use* MCP/tracing concepts, plus one adjacent competitor
(LangSmith). A narrower query was not re-run and might surface different entries.

## Source limitations, in one place

- Uber's numbers are self-reported and explicitly stated as not transferable to other codebases/teams; no second
  comparably rigorous public cost-equation post was found.
- GitHub documents Auto-selection's intent but not its routing model or a per-tier cost table — treat "cost
  efficient" as a vendor claim, not an independently verified benchmark, and avoid causal attribution to Auto alone.
- LinearB's and DORA's metrics are correlational delivery-outcome tools; neither claims causal isolation of AI-tool
  impact on productivity, and this digest doesn't either.
- Phoenix's remote MCP is explicitly "beta"; Langfuse's MCP reference site is the living source of truth for exact
  tools — re-check both before depending on specific tool names or defaults.
- No Grafana/LGTM MCP server was found in this pass; that's unresolved, not confirmed absent.
- Plan prices and AI-credit allowances are deliberately omitted here since they change — your Copilot contract and
  GitHub's live billing docs are authoritative, not this file.
