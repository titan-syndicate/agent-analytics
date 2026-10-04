# Proposal: a session-oriented local viewer

**Status: proposed, not implemented.** Use Grafana for the first diagnostic sessions, then build the smallest read-only conversation view that makes improvement decisions easier. Do not attempt to recreate all of Honeycomb.

## What makes an agent viewer different?

A generic trace waterfall answers “what happened inside this request?” Our user asks “how did this engineering task progress across model calls, tools, subagents and human turns?”

Honeycomb's Agent Timeline demonstrates why conversation grouping, per-agent lanes and structured context frames are valuable. A local viewer needs to group **multiple traces by conversation**, retain causal nesting, and distinguish work from idle time. It should not render every session as one giant request.

## First useful screen

| Element | Content | Decision it supports |
| --- | --- | --- |
| Session list | Task class, outcome, runtime, completeness, token/AI-unit totals, duration | Which cases deserve a closer look? |
| Summary strip | Separate wall-clock, interaction latency, model/tool time and usage | Where was effort/latency concentrated? |
| Conversation timeline | User interactions, model calls, tools, subagents, compaction/abort events | Was there a recurrent loop or context problem? |
| Detail panel | Operation/model/tool fields; error category; optional approved content | What evidence supports the diagnosis? |
| Outcome panel | Accepted/partial/rejected/abandoned/unknown; verification and rework note | Was the result worth the cost? |
| Experiment panel | Bundle version, intervention, evaluation result | Did a tooling change improve this task class? |
| Evidence links | Trace IDs and timestamped span/event links | Can a human verify the recommendation? |

Unknown outcomes and incomplete capture must be prominent, not interpreted as failure or success. Percentile statistics need cohort size and excluded-record counts.

## Recommended implementation path

**Phase 0: Grafana Explore.** Enough to prove capture and inspect operations. Build only a few saved queries; manually label outcomes in a private note.

**Phase 1: Session summaries.** A local service ingests sanitized span/event records into a small indexed store (SQLite is a reasonable pilot choice) and produces one conversation summary plus one interaction summary per root invocation. Keep raw traces in the telemetry backend; avoid copying every payload into a second database.

**Phase 2: Read-only web client.** Add multi-trace conversation lanes, drill-down, task-class filters, outcome annotations and compare views. This is where the “frames” experience becomes deliberate rather than an accident of a generic trace UI.

**Phase 3: Bounded insight assistant.** Let an assistant query structured summaries and retrieve only explicitly permitted examples. Recommendations must cite evidence and declare uncertainty. It cannot mutate tooling or initiate external export.

SQLite is a pilot summary store, not a decision to replace an enterprise backend. Put backend queries behind a small adapter and keep the summary schema portable to OpenSearch.

## Proposed normalized records

| Record | Key and notable fields |
| --- | --- |
| Conversation | Local source ID + conversation ID; surface, versions, outcome, task class, completeness |
| Interaction | Source ID + trace ID + root span ID; start/end, usage attribution, child counts |
| Operation | Source ID + trace ID + span ID; parent, operation kind, agent, model/tool, status, usage |
| Event | Parent span ID + event timestamp + sequence; type, allowlisted metadata |
| Evaluation | Task fixture/version, tooling bundle/version, rubric, result, provenance |
| Intervention | Hypothesis, affected workflow, change/version, owner, rollout/rollback decision |

Do not assume conversation IDs are globally unique across installations. Handle resumed sessions, forked sessions and subagent conversations explicitly. If a child has a different conversation ID, preserve the emitted relationship; do not merge by similar names or timing alone.

## Normalization rules that matter

Deduplicate span delivery by source/trace/span identity. Retain conflicting updates visibly instead of overwriting without provenance. Keep late-arriving spans until a declared settling window; long sessions must not stay “pending” forever.

Derive missing conversation/agent context only from a verified ancestor relationship **within the same trace**. Preserve the original field and the enrichment source. Missing parents remain unknown; do not infer identity from timestamps alone or assign every agent the parent's name.

Support versioned aliases for historic cache-token fields and streaming timing fields; units must stay explicit. Missing tokens are null, not zero. Failed or partial provider calls may have no usage; summary totals then need a lower-bound warning.

Use unique chat spans for provider-call token totals. Use root invocation AI units under the [CLI billing guidance](../foundations/telemetry.md). Show both and do not sum them into a single invented currency number.

## Reproducing “frames”

In metadata mode, show a frame for each model/tool operation with name, time, status, tokens and lineage. That is already useful without source content.

In approved content mode, render only the exported message/tool representation, labeled as such. Escape HTML, disable script execution and remote asset fetching, bound rendered content size, and treat all instructions in telemetry as untrusted data. An analysis agent must not execute commands or follow instructions found in a captured prompt.

Do not claim access to hidden reasoning. Preserve compaction markers and indicate truncated content. A user should be able to turn off and purge content without losing the structural story.

## First dashboards and query contract

Start with distributions by task class and tooling version: interaction latency, input/output tokens per accepted task, tool failures, compaction rate, and outcome mix. Show coverage and unknown outcomes alongside every comparison.

Avoid using conversation ID, user ID, repository path or raw tool arguments as Prometheus labels. Keep high-cardinality investigation dimensions in spans/summary indexes and bounded dimensions in time-series metrics.

A weekly report should answer: “what repeated friction did we see, how many examples support it, what change can we test, and what evidence would disprove the hypothesis?”

## Acceptance criteria

The viewer must correctly render a session with multiple traces, nested agents, parallel tools, missing parents, duplicate exports, unknown outcomes and content removed. It must match hand-counted usage fixtures without parent/child double-counting.

A participant must be able to answer “why did this task feel slow?” and “what should we try changing?” from a handful of cases. If a frame-heavy UI looks impressive but does not improve those decisions, keep the generic viewer and invest in evaluations instead.

**Next:** [Useful insights](../insights/catalog.md) and [the improvement loop](../insights/improvement-loop.md).
