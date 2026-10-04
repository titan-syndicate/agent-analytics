# Path from volunteers to 1,000+ engineers

**Scale the useful practice before scaling the raw data.** The likely end state is lightweight local capture with private drill-down plus sanitized enterprise summaries, not a mandatory Kubernetes stack and full-context archive on every laptop.

## Staged rollout

| Stage | Cohort | Focus | Gate for expansion |
| --- | --- | --- | --- |
| Discovery | 1-5 power users | Schema, safe capture, useful examples | Capture and privacy understood |
| Pilot | 10-20 opt-in engineers | One repeatable tooling intervention | Better workflow, trusted installation, known gaps |
| Expansion | Roughly 50-100 | More task/repository types; installer and support | Stable versions, representative feedback, operating owner |
| Enterprise | 1,000+ eligible engineers | Managed policy, central aggregates, governed tooling | Consent/governance, capacity/cost, rollback and support proven |

Eligible seats are not simultaneously active clients. Capacity planning must use measured active sessions, burst concurrency and actual serialized payload size.

## Target architecture

```text
Engineer device / execution host
    -> local collector and policy
    -> private short-lived raw traces
    -> approved summaries / structural spans
    -> authenticated enterprise gateway
    -> OpenSearch or approved enterprise backend
    -> aggregate dashboards + evaluation / experiment registry

Local viewer continues to provide private session drill-down.
```

Remote/container sessions need an agent or endpoint on the actual execution host. Do not force a remote runtime through an unauthenticated public laptop port. Cloud sessions require a separate supported integration and are outside the local capture promise.

## Distribution that can grow

Use a signed/versioned installer or approved package channel, a pinned plugin/skill bundle, and a simple launcher. Do not require every engineer to manually edit shell profiles.

For early adopters, clone-and-run recipes are acceptable. For the whole organization, provide capability detection, safe upgrades, rollback, uninstall, opt-out, data purge and clear error messages. Use organizational managed settings only on clients that actually support the relevant keys; the desktop telemetry gap must remain visible.

Tilt is excellent for platform engineers' local development. It should be optional for ordinary engineers: a lightweight collector/summary agent with an optional on-demand viewer may be a better enterprise footprint. Revisit the packaging once the pilot proves what is needed.

## An illustrative sizing exercise

The following assumptions are **not Copilot workload measurements**:

| Variable | Illustrative assumption |
| --- | --- |
| Active users per day | 1,000 |
| Root interactions per user/day | 30 |
| Spans per root interaction | 40 |
| Serialized metadata per span | 2 KiB |
| Resulting span volume/day | 1.2 million spans |
| Raw serialized metadata/day | About 2.3 GiB |
| Seven days before indexes/replicas | About 16 GiB |

This excludes metrics, events beyond the assumed payload, queue copies, summaries, indexes, replicas, backups and query overhead. It is an arithmetic planning example, not a storage benchmark.

At 100 KiB per span with content, the same workload is about 114 GiB/day before those overheads. Repeated context/history can make content much larger and unevenly distributed. Measure p50/p95/max payload and actual retained bytes, not just mean span counts.

Burst ingestion matters more than a daily average. Load-test model/tool fan-out and exporter flushing after outages. Budget cost per accepted task and per useful investigation, not just cost per gigabyte.

## Reliability contract

Monitor collector queue depth, refused/dropped data, export latency/failures, backend ingest errors, disk growth and summary lag. Expose those to the user and central owner.

Collection must not block normal Copilot work indefinitely. Use bounded memory, timeouts and disk queues, with explicit failure indicators and documented data-loss behavior. If offline buffers overflow, do not mark affected sessions complete.

Deduplicate replayed spans and handle counter resets. A healthy enterprise collector cannot prove an unconfigured desktop session was captured; measure expected sessions through an independent launch/coverage signal where supported.

## Retention, sampling and cardinality

For a local pilot, retain complete structural conversations for a short window. At scale, prefer complete selected conversation cohorts, all failure/rare-case cohorts and bounded routine retention rather than arbitrary per-span sampling that destroys the story.

If sampling is introduced, retain sample-policy metadata, count unsampled totals through a separate valid metrics path, and disclose bias. Conversation sampling across many traces is harder than sampling one trace; tail samplers need enough buffering and cannot assume every session ends promptly.

Keep high-cardinality IDs in traces/search indexes, not metric labels. Bound model/tool/task/version label values, sanitize arbitrary paths, and avoid dynamic mappings of message JSON in OpenSearch.

## Ownership and governance

| Owner | Responsibility |
| --- | --- |
| Developer platform / AI enablement | User experience, tool bundles, evaluation fixtures, improvement loop |
| RE/SRE | Backend reliability, capacity, retention, upgrades and operational response |
| Security/privacy/legal | Approved data tiers, access, regional constraints, consent and incident handling |
| FinOps / finance | Billing reconciliation, budgets and value definitions |
| Engineering teams | Outcome rubrics, workflow context and review of interventions |

Do not leave a laptop pilot's backend choice as an accidental production architecture. If OpenSearch is already a supported service, evaluate its fit with RE/SRE early using [the shared fixture plan](../proposals/backends.md), then make an explicit operating agreement.

## What deserves automation later?

Automate capture validation, privacy checks, schema compatibility, recurring friction summaries, regression evaluations and staged rollout reports. Keep quality judgments and broad tooling mutations reviewed until the evidence is strong enough for a narrowly bounded automated action.

Organization-wide cultural change comes from proven shared capabilities, clear learning loops and trust. Centralizing a billion spans does not create that culture by itself.
