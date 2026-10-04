# What Copilot telemetry can tell us

**OTel gives us a structured execution record, not proof of correctness or complete access to an agent's mind.** This page summarizes the [official CLI monitoring reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#opentelemetry-monitoring), checked October 4, 2026.

## Four different things often called “metrics”

| Signal | What it contains | Best use |
| --- | --- | --- |
| Traces / spans | Timed operations connected by trace and parent IDs | Explain one interaction's model calls and tool execution |
| Metrics | Counters and histograms aggregated by bounded dimensions | Spot usage, latency and failure trends |
| Span events | A named event attached to an operation | Inspect compaction, truncation, hooks and skill invocation |
| Content | Optional messages, tool arguments/results and instructions | Debug approved examples; much higher privacy and volume risk |

The CLI documents traces, metrics and span events. An event attached to a span is **not automatically a standalone OTLP log record**. A backend that supports logs does not mean every client exports them.

## Interaction is not conversation

The CLI emits an `invoke_agent` span for an agent interaction, with `chat` and `execute_tool` children. A long user session can include many interactions and traces. `gen_ai.conversation.id` groups session activity; trace IDs explain causal nesting inside a trace.

Subagents also use `invoke_agent`. A viewer must distinguish top-level interactions from nested agent work and support multiple traces within one conversation. Do not count every invocation span as a new user session.

## Useful documented fields

| Field or signal | What it helps answer | Qualification |
| --- | --- | --- |
| `service.name`, `service.version` | Which runtime emitted this? | Record desktop app version separately when testing it |
| `gen_ai.conversation.id` | Which conversation does this belong to? | Documented on invocation/chat; verify coverage on tool spans |
| `gen_ai.operation.name` | Chat, agent invocation, or tool execution? | Required for operation-aware analysis |
| `gen_ai.request.model`, `gen_ai.response.model` | Which model was requested/resolved? | Auto routing means these may differ |
| `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens` | How much model input/output? | Invocation totals overlap child chat totals |
| `gen_ai.usage.cache_read.input_tokens` | How much cached input was read? | Check provider semantics before subtracting from total input |
| `gen_ai.usage.cache_creation.input_tokens` | How much cache was created? | Not available uniformly across providers |
| `gen_ai.response.time_to_first_chunk` | Streaming responsiveness | Seconds; a chunk is not necessarily one token |
| `gen_ai.tool.name`, `error.type`, span status | Which operations fail or take time? | Error status is not equivalent to a wrong engineering outcome |
| `github.copilot.turn_count` | Model round-trips in an invocation | Not the number of user messages |
| `github.copilot.nano_aiu` | AI-unit consumption | 1 AIU = 1,000,000,000 nano AIU; not currency |
| `github.copilot.cost` | Per-request billing model multiplier | **Not dollars and not a token price** |

The runtime can also expose `enduser.pseudo.id`. Pseudonymous does not mean anonymous; treat it as linkable personal data and remove it from shared summaries unless explicitly needed.

## Events worth inspecting

The CLI documents `github.copilot.session.compaction_start`, `compaction_complete`, and `truncation`; `github.copilot.skill.invoked`; hook start/end/error; session abort/shutdown; and exception events.

Recent release notes also describe `gen_ai.conversation.compacted=true` on chat spans after successful compaction. Older runtime versions may differ. Preserve event timestamps and names; compaction is a signal to investigate, not an automatic failure.

## Aggregation traps

**Never sum parent totals and their children together.** For token analysis, sum unique `chat` spans at the provider-call grain; use invocation totals only as a cross-check. For AI units, the CLI explicitly recommends the **root `invoke_agent` span** to avoid double-counting usage also stamped on child chat spans. Nested subagents need a documented attribution rule and fixtures before joining their totals.

Do not add a cumulative metric export repeatedly. Counter resets, histogram temporality and replayed exports require correct backend handling. Percentiles from histograms are bucket-based estimates; do not average daily p95 values into a “monthly p95.”

Concurrent spans overlap. Adding their durations gives work-time, not wall-clock latency. Session wall-clock time also includes idle/human time and is not active engineering effort.

## What full context does and does not mean

With `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true`, the CLI documents input/output messages, system instructions, tool definitions, and tool call arguments/results. This is the likely basis of the detailed frames you saw in Honeycomb.

It is still the **exported representation**, not guaranteed access to hidden reasoning, every internal state, or all history before export was enabled. Context may be compacted, truncated, omitted, redacted or dropped by payload limits. Instrumentation and backend parsing must both support the shape.

## What is missing for our goals?

| Desired conclusion | Why OTel alone is insufficient | Additional evidence |
| --- | --- | --- |
| The task was correct | A successful model response can be wrong | Tests, rubric, review and acceptance |
| The agent saved engineer time | Duration includes waiting and ignores rework | Voluntary time/rework feedback or matched-task study |
| A skill improved quality | Invoked does not mean causal benefit | Versioned interventions and comparable evaluation tasks |
| Actual monetary cost | Tokens/multipliers/AI units are not an invoice | Billing data, plan terms, rate card and reconciliation |
| A repeated call was waste | Repetition may be necessary | Sequence context, task class, optional approved content |
| Adoption caused faster delivery | Many factors changed together | Team-level outcomes and controlled/longitudinal comparison |

## Schema strategy

GenAI conventions are still marked **Development** in the [current upstream repository](https://github.com/open-telemetry/semantic-conventions-genai/tree/main/docs/gen-ai). Keep sanitized fixtures by runtime version, preserve raw field names, and version our normalization separately. Do not silently turn a missing field into zero or “success.”

In the [CLI 1.0.91 experiment](../experiments/cli-local-otel.md), the client emitted `gen_ai.client.inference.usage.*` counters and `gen_ai.client.inference.operation.*` token histograms, rather than relying on the earlier documented `gen_ai.client.token.usage` family. Discover actual emitted metric names and keep version provenance before building dashboards.

## When live export is unavailable

[Local app/CLI session files and SQLite](../guides/local-session-data.md) provide a documented retrospective input. They can support tool sequence/failure analysis and derived elapsed-time spans, but are not OTLP records. Some SDK events, including per-call `assistant.usage`, are ephemeral; saved history cannot recreate absent measurements. Keep native and derived provenance separate.

**Next:** [Local CLI capture](../guides/copilot-cli.md) or [the insight catalog](../insights/catalog.md).
