# Spot a pattern before calling it waste

**We want to explain Copilot usage—not declare every large session inefficient.** Start with a successful task of roughly the same kind, then ask what changed. The [demo](demo.md) gives you safe examples to practice on.

## The patterns worth inspecting first

| What catches your eye | What it might mean | What to check before acting |
| --- | --- | --- |
| Input grows across model calls | Too much retrieval/history, or genuinely difficult work | Task scope, cache categories, useful evidence and result |
| Output is unusually large | Unnecessary explanation or generated material | Was that output required and used? |
| Many model/tool calls | Retries, exploration, or a broken integration | Call sequence, failure type, accepted outcome |
| Several child agents for one prompt | Useful parallelism or duplicated work | Worker scopes, unique deliverables, root wall time |
| A larger resolved model | Routing mismatch or necessary capability | Requested/resolved fields, task difficulty, fixed-model comparison |
| Long tool waits | Environment/setup tax | Auth, runner availability, service latency |

These are **review candidates**, not universal thresholds. A “too many calls” rule needs a task class and a quality bar. We do not have a tested organization-wide threshold yet.

## Input, output and context are different questions

Look at input and output separately. Large input with small output suggests a different investigation from small input with long output.

Also separate **consumption across calls** from **context size on one call**. Four 20,000-token inputs consume 80,000 input tokens; they do not prove an 80,000-token context window.

Cache reads and cache creation matter. Different backends may show inclusive input or uncached input. Check the source categories before comparing tools. A high token count may have a different billing weight than you expect.

## Count the work once

For token analysis, use unique `chat` spans. Do not add root totals to their children's totals. For delegation, report root interactions and child agent invocations separately.

For latency, keep root wall time and child activity separate. Parallel workers overlap; summing their time overstates what the user waited.

Short-lived CLI processes can reset the same Prometheus series. Use traces for small-run attribution rather than treating `last_over_time` as a batch total. A chart showing no sample at “now” is also not the same as zero usage.

## Turn an outlier into a useful question

Suppose a test-backed fix has four failed test commands, then a successful one. Ask:

* Did the agent pick the wrong command, or was the runner unavailable?
* Could a preflight have told it the right command?
* Would that change preserve the tests we actually need?

That points to a maintainable tooling fix. “Prompt better” is much less actionable.

Now suppose three agents investigate different modules. Before capping fan-out, check whether the parallel work found evidence a serial approach would have missed. The expensive-looking trace could be the good one.

## Keep four measures separate

| Measure | What it tells us |
| --- | --- |
| Model-call tokens | Technical consumption and context/output patterns |
| Copilot runtime usage units/multipliers | Runtime billing signals when present, with their own grain |
| GitHub billing exports | Actual financial usage under our plan |
| Delivery and rework | Whether the investment produced useful work |

A public model price in Phoenix/Langfuse is not a Copilot invoice. Do not sum root billing units with child billing units either. Show missing values and incomplete capture rather than substituting zero.

## The best early insights end in a test

A useful finding sounds like: “On these test-backed tasks, a runner preflight might remove this repeatable setup loop. Let's compare it with the old workflow.”

It does **not** sound like: “The highest-token engineers are the least efficient.”

Require an outcome: accepted, partial, rejected, abandoned, or unknown. Compare like tasks, show sample size, and keep unknown outcomes visible. Without quality/rework evidence, lower usage is only lower usage—not improvement.

**Next:** [Use the improvement loop](improvement-loop.md) to decide what to change and whether to keep it.
