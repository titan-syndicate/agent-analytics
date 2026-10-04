# The first 30 days

**Prove capture, trust, and one improvement before solving enterprise deployment.** Recruit 10-20 opt-in engineers, including a few high-volume users, across two or three representative repositories. Include at least one skeptical participant and one desktop-first participant.

## Pilot charter

The question is: *Can local agent telemetry help us improve a recurring engineering workflow without compromising quality, privacy, or developer trust?*

Limit the first task classes to repository investigation and test-backed bug fixes. Exclude sensitive repositories unless specifically approved. Capture metadata only; reserve any content capture for a synthetic or explicitly approved debugging session.

The pilot's deliverables are a compatibility matrix, a small session review rubric, one versioned tooling experiment, and an evidence-backed keep/change/stop decision. A polished dashboard is not the success criterion.

## Weekly plan

| Week | Work | Exit evidence |
| --- | --- | --- |
| 1: Capture | CLI/local backend; desktop history fallback and live compatibility check; privacy inspection | Native trace or verified sanitized history summary; source/coverage recorded; no content in analytics output |
| 2: Baseline | Label accepted/partial/rejected/abandoned outcomes; review typical and outlier sessions | At least 20 labeled comparable tasks; known gaps and missing data reported |
| 3: Intervention | Improve one skill or integration; pin its version; run matched tasks | Same evaluation rubric applied to baseline and treatment |
| 4: Decision | Examine quality, latency, usage and engineer feedback together | Written decision, counterexamples, rollback plan, next hypothesis |

Twenty tasks are a learning floor, **not a statistical power guarantee**. If there are too few failures to assess a quality regression, call the result inconclusive rather than declaring equivalence.

Desktop-first participants can use [documented local session history](../guides/local-session-data.md) while live export is unresolved. Mark results as retrospective and keep missing usage/timing visible. Do not compare native and reconstructed measurements as if their coverage were identical.

## A lightweight review record

Record these fields in a private local note or future session-summary store, not the public docs repository:

```yaml
task_class: test_backed_bugfix
runtime_version: recorded_from_client
client_surface: cli
tooling_bundle_version: baseline
outcome: accepted
verification: targeted_tests_passed
human_rework_minutes: 10
friction_category: tool_environment
capture_complete: true
```

`human_rework_minutes` is optional self-report, not a time-tracking requirement. Avoid identifiers that expose repository names or people in shared aggregates.

## Proposed pilot gates

These thresholds are starting decisions to negotiate, not established SLOs:

| Gate | Proposed threshold | If it fails |
| --- | --- | --- |
| Capture reliability | At least 95% of deliberately launched pilot interactions have expected telemetry | Fix capture before interpreting outcomes |
| Privacy | Zero known content fields in metadata-mode exported fixtures and inspected real sessions | Stop export, purge affected data, repair the boundary |
| Usability | A new participant can get a synthetic trace visible within 15 minutes after prerequisites | Simplify installation or offer a Compose path |
| Improvement | At least one repeatable intervention shows lower friction with no observed quality loss | Continue exploration or stop; do not mandate usage |
| Trust | Participants know what is collected and how to stop/delete it | Do not expand the cohort |

Measure capture coverage against an independent launch count or participant task log. A collector's own accepted-span count cannot reveal sessions that never reached it.

## Ownership and stop conditions

An enablement lead owns experiment design; a platform engineer owns capture; a privacy/security partner reviews the data contract; participants own whether their private examples are shared. The RE/SRE team should advise on backend operations without inheriting a premature production service.

Stop the pilot if data leaves the machine without consent, the viewer exposes another participant's content, collection degrades normal work, or the project becomes individual performance surveillance.

## Day-30 decision

Expand to roughly 50 engineers only if a repeatable tooling change helped and installation/capture are trustworthy. Otherwise keep the local experiment small. Carry forward negative results: “the viewer was useful, but tokens alone could not explain quality” is a valuable finding.

**Next:** [The improvement loop](../insights/improvement-loop.md) describes how this becomes an enduring practice.
