# Better agent workflows, not just more telemetry

**Start locally, inspect a few real sessions, improve one workflow, and measure whether it helped.** This field guide is for engineers and platform teams investigating how to make AI-assisted development more consistent and efficient.

The goal is not an individual productivity scoreboard. It is an evidence-based engineering practice: understand where agents spend time and tokens, where tools fail, and which reusable instructions, skills, and integrations reliably improve an accepted outcome.

!!! tip "The recommended starting point"
    Read [recommendations for high-volume users](start/recommendations.md) first. Use Copilot CLI with a local OpenTelemetry backend for the initial experiment. Keep message content off. Treat desktop capture as a compatibility gate, not an assumption.

Desktop-first users can start with [saved local session data](guides/local-session-data.md) instead of waiting for live export. GitHub documents both app and CLI history in the local session directory/index; retrospective analysis has different privacy boundaries and cannot recover unpersisted metrics.

**The local CLI path has now been exercised:** [read the experiment result](experiments/cli-local-otel.md), then [run the checked-in Tilt lab](guides/local-lab.md). For a more agent-specific UI than Grafana, [compare Phoenix and Langfuse on the same traces](guides/viewer-comparison.md).

**Ready to generate and inspect data?** [Run a series of CLI one-shots and find the results](guides/generate-and-find-data.md), including why Grafana's bundled dashboards are empty and how to query metrics after a CLI exits. Capture requires the launcher; Tilt alone does not globally instrument `copilot`.

**Our current objective is Copilot cost management.** We have billing and a LinearB delivery view, but not yet an explanation of what drives usage. Start with [the cost objective](insights/cost-objective.md), then [the six-scenario demo](insights/demo.md). It teaches context/output growth, retry loops, fan-out and model comparisons without paid inference. The local helpers are now Bash, not Python.

**New to model telemetry or these viewers?** Read [from a request to model calls](foundations/model-calls.md), then use the separate [Grafana](insights/demo-grafana.md), [Phoenix](insights/demo-phoenix.md) and [Langfuse](insights/demo-langfuse.md) walkthroughs. They explain what to click, what the rows mean and which questions the data cannot answer.

## Choose a reading path

| Your question | Start here | Then read |
| --- | --- | --- |
| What should I try this week? | [High-volume recommendations](start/recommendations.md) | [First 30 days](start/pilot.md) |
| Can I see my local sessions? | [CLI capture](guides/copilot-cli.md) | [Tilt + Kubernetes lab](guides/local-lab.md) |
| Will the desktop app work? | [Desktop compatibility](guides/desktop.md) | [Capture proposal](proposals/capture.md) |
| Can I analyze existing app history? | [Local session files and SQLite](guides/local-session-data.md) | [Improvement loop](insights/improvement-loop.md) |
| How did Honeycomb show agent context? | [Honeycomb setup](guides/honeycomb.md) | [Viewer proposal](proposals/viewer.md) |
| Should we use OpenSearch? | [Backend decision](proposals/backends.md) | [Enterprise scaling](enterprise/scaling.md) |
| What will we actually learn? | [Insight catalog](insights/catalog.md) | [Improvement loop](insights/improvement-loop.md) |
| Is this AIOps? | [Naming the practice](foundations/practice.md) | [Privacy and trust](enterprise/privacy.md) |

## The working recommendation

Use **OpenTelemetry as the collection contract**, not as a competing database. Start with Grafana's local development LGTM backend for traces, metrics, and logs; use Tilt when Docker Desktop Kubernetes is already part of your workflow. Grafana is a good first diagnostic viewer, but it is not a drop-in replica of Honeycomb's Agent Timeline.

Keep Honeycomb as an optional, explicitly approved reference experience. Evaluate OpenSearch against the same sanitized fixtures when central retention and existing enterprise operations matter. Do not move 1,000 engineers onto a backend before proving the improvement loop works for 10-20 volunteers.

```text
Copilot runtime
    -> OTLP
    -> local collection / policy boundary
    -> traces + metrics + session summaries
    -> human review and bounded experiments
    -> versioned skills, tools, instructions and evaluations
    -> measured rollout or rollback
```

## What is real, and what is proposed?

| Item | Status in this repository |
| --- | --- |
| Navigable MkDocs site and GitHub Pages publication | Implemented |
| Copilot CLI OTel configuration | Documented upstream capability; setup guide |
| Local LGTM with Tilt | Implemented development lab; CLI end-to-end capture verified |
| CLI lab helper / smoke verification | Implemented; not a packaged enterprise installer |
| Honeycomb Agent Timeline | Documented upstream capability; setup guide |
| Desktop OTel capture | Unverified; managed telemetry support is explicitly limited upstream |
| Local app/CLI history and `/chronicle` | Documented upstream capability; retrospective analysis guide |
| Session-file importer / derived OTel spans | Proposed, not implemented |
| One-command launcher / installable skill | Proposed, not implemented |
| Session-oriented local web client | Proposed, not implemented |
| Phoenix / Langfuse integration | Deployed together; synthetic and CLI trace fan-out verified |
| Automated insight and experiment service | Proposed, not implemented |

## Read the evidence, not promises

Client and GenAI telemetry schemas change quickly. The [telemetry reader](foundations/telemetry.md) separates observed metadata from missing outcomes. The [source register](reference/sources.md) records the official references checked on **October 4, 2026**, including caveats about desktop support and billing units.

This is a public documentation site. It does not receive, store, or display actual Copilot telemetry.
