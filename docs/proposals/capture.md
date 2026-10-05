# Proposal: local capture and easy distribution

**Status: proposed, not implemented.** Build a small local “agent analytics” launcher around OTLP and a reviewed collection boundary. Tilt is one deployment adapter, not the product's interface and not a requirement for every engineer.

The first development slice now exists as [Tilt plus `scripts/lab.sh`](../guides/local-lab.md), with [verified CLI capture](../experiments/cli-local-otel.md). The packaged command below, privacy gateway, distribution skill, durable retention and desktop adapter remain proposals.

## Decision and rationale

Keep the client-to-collector contract vendor-neutral. Separate three concerns: starting services, enabling a particular runtime, and deciding what may be retained/exported. This avoids treating “Tilt is running” as “desktop capture works.”

The first implemented slice should support the verified CLI path, metadata-only collection, a synthetic check, and a read-only diagnostic UI. Desktop support is a release gate with a capability matrix, not a marketing claim.

For desktop-first users, add a separate [local-history adapter](../guides/local-session-data.md) using documented session files/indexes. This does not depend on live desktop OTel configuration, but its parser and field coverage need version-specific verification. Label it retrospective/derived, not native capture.

## Alternative input: local session history

Start with explicitly selected completed sessions. A native host reader opens event logs or the session index read-only, sanitizes to allowlisted metadata, and produces the same normalized session summaries as native OTel. Do not mount `~/.copilot` wholesale into the Tilt backend or upload it.

Only reconstruct spans for operations whose start/end and identity are evidenced. Tool-call IDs can pair tool events; an event's `parentId` chain is chronological, not a span-parent tree. Missing ephemeral usage stays missing, and overlapping native/imported records must not be double-counted.

The proposed launcher can later add `import --session ID` and `verify --source session-files`, with explicit user selection, adapter/version reporting, privacy checks and completeness status. These are **not implemented commands**. A successful import proves history analysis for that session, not live app telemetry coverage.

## Proposed architecture

```text
Client adapter (CLI first; desktop if verified)
    -> local OTLP Collector / policy gateway
       - size and memory limits
       - resource/attribute allowlist
       - content mode enforcement
       - schema tagging and normalization
       - bounded retry/queue and visible failure counters
    -> local telemetry backend
    -> versioned session-summary builder
    -> viewer and experiment records

Optional, explicit export:
    sanitized pipeline -> approved enterprise gateway or Honeycomb
```

The [LGTM lab](../guides/local-lab.md) goes directly to its bundled collector and does not implement the policy gateway. Do not mistake that lab for this architecture. A separate edge collector can forward to LGTM's internal receiver on a different port, with no second direct client route around the policy boundary.

## Proposed command contract

These commands illustrate the intended UX; **they do not exist yet**:

```text
agent-analytics doctor
agent-analytics up --backend lgtm --orchestrator tilt
agent-analytics verify --synthetic
agent-analytics run -- copilot
agent-analytics status
agent-analytics report --period week
agent-analytics down
agent-analytics purge --before DATE
```

| Command | Required behavior |
| --- | --- |
| `doctor` | Detect tools, runtime versions, occupied ports and cluster context; never silently switch context |
| `up` | Idempotently start only owned services; print addresses, retention and capture mode |
| `verify` | Submit a synthetic fixture and read it back from storage, with timeout and explicit failure |
| `run` | Launch a new process with explicit local export and content-off settings; preserve exit code |
| `status` | Distinguish backend ready, client configured, signals observed, policy verified |
| `report` | Use a pinned summary schema; show missing-data warnings and evidence links |
| `down` | Stop owned processes/forwards without purging data by surprise |
| `purge` | Preview exact owned data scope and require consent before deletion |

No auto-install into a running app bundle, global environment injection, privileged daemon, or telemetry sent externally by default. Starting the tool must never require a Honeycomb key.

## Tilt adapter

Use a dedicated namespace, explicit `docker-desktop` context guard, pinned images/digests and loopback-only forwards. Health checks must cover receiver **and storage**, not merely Pod readiness.

Store only private local configuration outside source repositories. Add a Compose adapter for engineers without Kubernetes. Both adapters expose the same loopback OTLP endpoint and user-facing capability/status model.

A standard installer should budget laptop memory/CPU, storage cap, startup time and background footprint. For the pilot, proposed budgets are a 4 GiB service memory ceiling and a 5 GiB telemetry disk cap; measure real workloads before treating them as defaults. On pressure, make data loss visible rather than silently discarding sessions.

## Skill as a thin interface

A future installable skill can orchestrate the launcher after explicit user intent. Its role is not to implement privileged setup or overwrite global instructions.

An illustrative skill instruction would be:

```text
When the user requests local agent analytics:
1. Run doctor and report unsupported client surfaces.
2. Confirm local-only metadata capture and the intended execution host.
3. Start the user's selected adapter without changing cluster context.
4. Run the synthetic read-back check.
5. Explain whether a new client/runtime launch is needed.
6. Return the viewer link and exact stop/purge instructions.
Never enable content capture or external export without explicit consent.
```

The app documents that CLI/repository skills are available in desktop sessions. That makes distribution promising, **not proof that a skill can enable OTel in its existing parent process**. The skill may require the user to start a newly configured session.

## Capture contract, version 1

| Area | Proposed requirement |
| --- | --- |
| Default | Metadata only; no network export beyond loopback |
| Identity | Local random participant/workstation ID only when needed; no username or raw path |
| Trace storage | Original IDs and timestamps preserved; unique spans deduplicated |
| Signals | CLI traces/metrics/events verified separately; unsupported signals shown as unsupported |
| Content | Explicit opt-in, session-scoped, time-limited; separate protected store |
| Retention | Proposed 7-day raw metadata and 30-day content-free summaries; verify expiration |
| Disk limits | Hard cap with warning and explicit eviction policy; never pretend data is complete |
| Offline use | Bounded queue; overflow/export failures visible to the user |
| Schema | Preserve emitter/runtime version; record normalization version and field availability |
| Export | Allowlisted sanitized summaries first; raw structural spans only by approved policy |

Persisted queues contain telemetry too. They need the same permissions, deletion policy and storage cap as the backend.

## Acceptance tests before calling it installable

Test a clean installation, occupied ports, wrong cluster, stopped Docker, memory pressure, exporter outage, normal shutdown, process crash, restart and upgrade. Verify that the launcher never kills unrelated processes or deletes another namespace.

For data, use sanitized fixtures covering model calls, tools, nested agents, multiple traces per session, compaction, missing usage, old field names and duplicate delivery. Verify the metadata policy rejects content in resource attributes, spans, events, logs and metric labels.

For desktop, require an app-specific exported task and privacy inspection on each claimed surface/version. “A CLI process exported successfully on that machine” is not enough.

## Delivery sequence

1. CLI wrapper plus local diagnostic backend and synthetic test.
2. Reviewed privacy allowlist, bounded storage and completeness status.
3. Session summaries and a weekly local report.
4. Optional skill distribution and desktop adapter only after verification.
5. Opt-in sanitized central export once experiments justify it.

**Next:** [Session viewer and analysis](viewer.md) defines what people will actually read.
