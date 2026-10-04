# Local OTel, Honeycomb and OpenSearch: the real tradeoff

**Recommendation: keep OTLP portable, learn locally, and evaluate the enterprise store independently of the viewer.** OpenTelemetry is a collection/instrumentation framework, not a competitor to Honeycomb or OpenSearch. All three can coexist at different points in the pipeline.

## Separate the layers

| Layer | Candidates | What we should standardize |
| --- | --- | --- |
| Instrumentation | Copilot's built-in OTel, SDK/tool instrumentation | Signal meaning and versioned fixtures |
| Collection/policy | Local Collector, enterprise Collector gateway | Privacy, routing, limits, reliable delivery |
| Durable storage/query | Tempo/metrics/log stores, Honeycomb, OpenSearch | Retention, access, cost and query needs |
| Agent-oriented experience | Honeycomb Agent Timeline, proposed local viewer | Conversation model, frames, outcome comparisons |
| Improvement process | Evaluation suite, experiment registry, enablement practice | Accepted outcomes and controlled interventions |

Moving storage to OpenSearch does not require abandoning OTel. Keeping a local viewer does not require a laptop-sized copy of the enterprise backend.

For local agent-specific presentation rather than generic trace waterfalls, [Phoenix and Langfuse](agent-viewers.md) are additional candidates. Their trace/agent analytics do not automatically replace the Prometheus metrics path; verify Copilot semantics before treating OTLP acceptance as full UI compatibility.

## Decision matrix

| Concern | Local LGTM + summaries | Honeycomb | OpenSearch + Data Prepper/Dashboards |
| --- | --- | --- | --- |
| First safe local experiment | Strong: no external export required | Needs approved SaaS ingest and key | More components and resource/operational setup |
| Trace investigation | Strong generic traces; agent view needs work | Strong trace and conversation-oriented experience | APM/trace analytics supported; agent-specific semantics need evaluation |
| Agent frames / multi-trace sessions | Proposed custom layer | Agent Timeline documented | Do not assume parity; likely mappings/UI work |
| Numeric metrics | Local metrics backend | OTLP metrics with dataset routing | Current APM architecture also uses Prometheus |
| Flexible enterprise search | Pilot summary index; limited shared governance | High-cardinality observability queries | Strong indexed document search; explicit schema design matters |
| Raw content risk | Stays local, but laptop storage is still sensitive | Content leaves device; approvals/region/access needed | Centralized content still requires strict access/retention |
| Operational ownership | Engineer/enablement team for pilot | Vendor operates platform; ingest governance still ours | RE/platform team operates pipelines, indexes, upgrades and access |
| Cost profile | Laptop resources plus implementation/maintenance | Ingest/retention/plan spend; verify current contract | Infrastructure, replicas, storage and significant operator time |
| Offline/local usability | Strong if laptop backend is healthy | Export queues only; remote viewing needs connectivity | Local deployment possible, but comparatively heavy |
| Evaluation/outcome labels | We must add them | We must integrate them | We must integrate them |
| Long-term fit | Personal exploration and sanitized edge summaries | Fast investigation if SaaS is approved | Good candidate when central platform and operational expertise already exist |

These are architectural assessments, not benchmark results or a feature/pricing guarantee.

## Why the RE preference may make sense

An existing OpenSearch platform may already have authentication, tenant isolation, backups, retention policies, capacity planning and an operations team. Reusing those controls can be a better enterprise decision than introducing another SaaS or a new distributed storage stack.

OpenSearch is attractive for structured session summaries, search, cohort aggregations and joins through denormalized records. Store useful normalized dimensions explicitly; avoid dynamically indexing arbitrary prompt JSON or every tool argument. Mapping explosions and large text payloads can dominate cost and make deletion harder.

## What OpenSearch does not automatically give us

The current [APM documentation](https://docs.opensearch.org/latest/observing-your-data/apm/index/) labels its integrated APM experience **introduced in 3.6**. It describes an OTel Collector, Data Prepper, OpenSearch, Prometheus and Dashboards. This is distinct from older trace/application analytics. Verify the enterprise's actual versions before copying “latest” recipes.

The [unified Data Prepper OTLP source](https://docs.opensearch.org/latest/data-prepper/pipelines/configuration/sources/otlp-source/) supports gRPC and HTTP/protobuf, **not HTTP/JSON**. Its documented default port is 21893, not automatically 4318, and its default unframed HTTP paths differ from standard `/v1/*` paths. A Collector is a useful compatibility boundary.

The official current [ingestion architecture](https://docs.opensearch.org/latest/observing-your-data/apm/configuring-telemetry-ingestion/) routes traces/logs to Data Prepper and metrics to Prometheus. “Send everything straight to the OpenSearch REST endpoint” is not a valid OTLP design.

An agent conversation has many traces and optional messages/tool results. A service map or trace waterfall is not automatically a Honeycomb-style agent timeline. We should test that UX directly and budget for our own session summary/viewer layer if it is missing.

## Recommended evaluation, not a migration leap

Keep a small sanitized fixture set containing:

* A typical successful bug fix and a long investigation.
* Nested agents and multiple traces in one conversation.
* A failed/aborted operation, compaction and missing usage.
* Duplicate/late spans and a historical schema variant.
* Synthetic content-only frames for UI testing, never production source.

Evaluate local storage, Honeycomb and the organization's exact OpenSearch stack against the same records.

| Test | Measure |
| --- | --- |
| Find an expensive accepted task | Query latency, steps needed, correctness of attribution |
| Explain a tool retry loop | Conversation grouping, errors, causal sequence, evidence links |
| Detect a tooling regression | Task/version filters, quality labels, missing-data treatment |
| Delete a content session | Actual removal from indexes, queues, replicas/backups under policy |
| Change schema version | Mapping compatibility, null handling, fixture fidelity |
| Operate under burst load | Queue depth, dropped records, query latency, storage growth |

Use measured engineer minutes per investigation as well as infrastructure cost. A cheaper store with a confusing viewer can cost more overall.

## A sensible long-term hybrid

Keep raw detailed content local unless an exception is approved. Export sanitized structural data and content-free session summaries to the enterprise gateway. If OpenSearch wins, use it for central summaries/trace investigation and the viewer's query adapter; retain a suitable metrics store.

Honeycomb can remain an opt-in reference or debugging environment, but avoid dual-writing all raw content by default. Every additional copy complicates consent, spend, deletion and breach scope.

Choose central technology only after the pilot identifies which questions people ask regularly. **Backend selection cannot substitute for outcome labels and an improvement process.**

**Next:** [Scaling to 1,000+ engineers](../enterprise/scaling.md).
