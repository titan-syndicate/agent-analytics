# Agent-focused web viewers beyond Grafana

**Recommendation: evaluate Phoenix first for a lightweight local agent view, and Langfuse when the evaluation/experiment workflow becomes the priority.** Keep Grafana's Prometheus backend for numeric telemetry. These products focus largely on enriched traces and derived analytics; they do not automatically replace every OTLP metrics pipeline.

The repository's Tilt deployment now runs **Grafana, Phoenix and Langfuse** with shared trace fan-out. Follow the [local comparison guide](../guides/viewer-comparison.md). The feature comparison below remains a research guide, not proof that every Copilot field/evaluation feature works.

## The main choices

| Viewer | Agent-oriented experience | Local deployment | Copilot integration caveat |
| --- | --- | --- | --- |
| **Phoenix** | Model/tool/agent spans, sessions, annotations, datasets and evaluations | Docker/Kubernetes; SQLite or PostgreSQL | Rich rendering uses OpenInference conventions; validate GenAI mapping/enrichment |
| **Langfuse** | Session/trace views, generation details, usage, scoring, datasets and experiments | Docker Compose or Kubernetes; a larger multi-service stack | Native OTLP HTTP ingest and GenAI mappings, but session/field propagation needs verification |
| **Honeycomb** | Conversations, Agent Timeline, per-agent lanes and optional context frames | Managed SaaS | Closest documented reference experience; not a local deployment |
| **Grafana LGTM** | Generic span waterfalls and numeric metrics exploration | Already running in this lab | Good capture diagnostic, not an agent-native conversation/evaluation UI |
| **A custom thin viewer** | Our exact session summary/outcome/improvement workflow | Proposed local service | Maximum control, but we own implementation and maintenance |

## Phoenix: first local candidate

[Phoenix self-hosting](https://arize.com/docs/phoenix/self-hosting) documents tracing, annotations, datasets and experiments with Docker/Kubernetes deployment. Its [Docker guide](https://arize.com/docs/phoenix/self-hosting/deployment-options/docker) supports a lightweight local server with optional SQLite storage; the web UI and HTTP trace receiver use port 6006.

The [OpenInference guide](https://arize.com/docs/phoenix/cookbook/tracing/openinference-best-practices) explains the rich semantics: `LLM`, `TOOL`, `AGENT` and related span kinds, session identity and message details. OpenInference extends OTel, rather than replacing OTLP.

Copilot emits OTel GenAI operation/model/tool attributes. Receiving those spans is not proof that Phoenix displays the right operation kinds, tokens or sessions. Inspect the selected version's conversion behavior and, if needed, add a narrow reviewed mapping in the Collector:

```text
Copilot invoke_agent -> OpenInference AGENT
Copilot chat         -> OpenInference LLM
Copilot execute_tool -> OpenInference TOOL
conversation ID      -> verified session identity mapping
```

The checked-in Collector implements this operation/session mapping when source attributes are present. Preserve original fields, subagent identity, timestamps and missing-data state. Verify whether the same conversation spans multiple traces and whether tool spans need ancestor-based enrichment.

## Langfuse: strong fit for the improvement loop

[Langfuse OTLP ingest](https://langfuse.com/integrations/native/opentelemetry) supports HTTP/protobuf and HTTP/JSON, maps GenAI attributes, and documents a local endpoint under `/api/public/otel`. Its current v4 docs require the ingestion-version header for real-time behavior, alongside project-key authentication.

The mapping docs list session fields such as `langfuse.session.id` / `session.id`; do not assume Copilot's `gen_ai.conversation.id` automatically populates the session view. Trace-level attributes needed for filters/aggregations should be propagated across relevant spans under the documented model.

Its [self-hosted Compose guide](https://langfuse.com/self-hosting/deployment/docker-compose) gives the deployment path, but Langfuse needs more infrastructure and secrets than the minimal local Phoenix trial. It is worth that investment when scored outcomes, datasets, prompt/version comparison and ongoing experiments are actively used.

Langfuse's UI commonly uses port 3000, already occupied by Grafana here. Our side-by-side deployment forwards it to loopback port **3001** and uses explicit trace routing. Do not point Copilot's metrics exporter at a trace-only endpoint.

## Preserve the current collection boundary

The current deployment routes the same structural traces locally:

```text
Copilot -> local Collector
    -> Tempo / Grafana for raw diagnostics
    -> mapping/enrichment -> Phoenix AND Langfuse for agent views
    -> Prometheus for numeric metrics
```

Do not instrument model calls twice merely to populate another UI. Use a Collector branch with tested semantics and keep usage attribution consistent. More destinations mean more storage copies and deletion obligations, even locally.

Content-off traces can still give operation kind, timing, model and token details. Actual prompt/response text is absent; Phoenix may display a metadata-only response envelope. Test rich message rendering with **synthetic content only**; neither viewer justifies broad real-context capture.

## The shortest useful evaluation

Send the same sanitized fixtures to each candidate, then answer:

1. Are model/tool/agent operation types rendered correctly without invented hierarchy?
2. Do several traces group into one conversation, with distinct subagents?
3. Are input/output/cache usage fields shown accurately, without doubled parent totals?
4. Are missing fields and partial traces visibly incomplete?
5. Can a participant label an outcome and compare a pinned tooling change?
6. Can we disable content, prevent unapproved egress and delete all copies?

Measure the time to diagnose an actual retry loop, not just how attractive the waterfall looks. Use the shared local lab to compare both; choose Langfuse if its broader evaluation workflow is the value you need. The earlier CLI-to-LGTM experiment is historical evidence, not a full viewer benchmark.

**Next:** [Session viewer proposal](viewer.md) defines our desired workflow regardless of product.
