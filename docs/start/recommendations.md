# Recommendations for high-volume Copilot users

**Capture structure first, learn from expensive or frustrating sessions second, and optimize a repeatable workflow third.** High-volume users give us enough examples to find recurrent friction quickly, but also generate enough data to make indiscriminate content capture a bad default.

## The first setup to choose

| Decision | Recommendation | Why |
| --- | --- | --- |
| Initial client | Copilot CLI, then a separate desktop experiment | CLI export is documented; desktop inheritance and support need proof |
| Capture protocol | OTLP over HTTP/protobuf | Explicit compatibility across backends; do not rely on the CLI's HTTP/JSON default |
| Backend | Local Grafana LGTM development image | One backend package for traces, metrics, logs and a web UI |
| Orchestration | Tilt + Docker Desktop Kubernetes if already installed | Visible health, logs and localhost forwarding; no reason to add Kubernetes just for first capture |
| Content | Off by default | Token counts, timings and failure metadata answer many initial questions |
| Sampling | Keep all structural telemetry in a bounded local pilot | Missing parts of conversations undermine loop analysis; bound retention instead |
| Retention | Proposed 7 days of raw metadata; 30 days of content-free summaries | Enough for weekly learning without indefinite laptop archives |
| First dashboard | Model call latency/tokens, tool failure rate, long interactions | Actionable operational friction, not a vanity usage chart |
| First experiment | A reliable test-running or repository-navigation skill | Repeatable, measurable, relatively easy to verify |

The retention values are **policy targets**, not defaults implemented by the lab image. Configure and verify expiration before retaining real telemetry beyond a short experiment.

## What to inspect each day

Spend ten minutes looking at three cases: a successful typical task, a high-token task, and a frustrating or failed task. Comparing only failures tells you what went wrong, but not what a good path looks like.

For each case, record a coarse task type, whether the result was accepted, the main source of friction, and one possible change. Do not copy prompts or source code into shared notes.

| Pattern | First question | Likely intervention |
| --- | --- | --- |
| Many model calls before the first useful tool call | Was repository discovery too vague? | Improve the repository map or navigation skill |
| Repeated failed tool calls | Is it a permissions, schema, auth, or command problem? | Repair the integration; add a deterministic preflight |
| Repeated compaction or sharply growing input tokens | Was too much irrelevant context loaded? | Narrow retrieval; summarize task state explicitly |
| Slow tool spans | Is setup repeated every turn? | Cache safe setup or provide a dedicated tool |
| Expensive model use for routine work | Could a less expensive configuration pass the same tests? | Run a matched-task experiment, not a blanket model downgrade |
| Fast, cheap sessions with rejected results | Did we optimize away the quality check? | Strengthen verification and outcome labeling |

These are hypotheses. A long session may be careful engineering, and a repeated tool call may be legitimate pagination. [The insight catalog](../insights/catalog.md) explains what additional evidence is needed.

## A practical first week

1. Bring up the [local lab](../guides/local-lab.md) and send synthetic telemetry before a real session.
2. Start a fresh CLI process using the [explicit local environment](../guides/copilot-cli.md). Record the runtime version.
3. Run a small, non-sensitive task. Confirm model and tool spans appear, and content does not.
4. Collect 10-20 sessions across two recurring task types, including outcomes.
5. Identify one repeated friction pattern; change one skill, tool, or instruction.
6. Compare the next matched set for accepted outcomes, interaction duration and usage, then retain or roll back the change.

## What not to do

Do not enable full context across every repository, equate tokens with currency, or use lines generated as value. Do not rank engineers by spend or infer organizational ROI from an enthusiastic volunteer sample. Do not ask an agent to automatically rewrite global instructions based on a dashboard spike.

For high-volume users, the useful unit is usually **accepted task within a task class**, not “total prompts.” The pilot needs lightweight outcome labels because raw OTel does not know whether the engineering result was good.

**Next:** [First 30 days](pilot.md) turns this into a bounded team experiment.
