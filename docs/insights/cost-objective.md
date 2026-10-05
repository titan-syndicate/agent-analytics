# Start with the bill, then explain the work

**Our first goal is to understand and manage GitHub Copilot costs over time.** ROI is where we want to get, but we are not there yet. Today we can see what we paid. We cannot explain which parts of agent work made that bill larger.

We have theories: too much context, long answers, repeated attempts, lots of subagents, or a larger model than a task needs. Those are useful places to look—not conclusions about what our engineers are doing.

## What we have today

**GitHub billing** tells us about financial usage under our contract. Keep it as the source of truth for spend, including the distinction between seats, included allowances and variable usage. Do not replace it with a viewer's public-model price estimate.

**LinearB** gives managers a delivery view: Git/PR activity, timing, throughput and the AI adoption/impact dashboards we already use. Our current use of those dashboards is a loose association between AI utilization and throughput. That is useful context, but it cannot explain a particular model call or prove AI caused a throughput change.

**Local OTel** adds a third view: what happened inside an agent interaction. Which models ran? How much input/output did they consume? How many tools, retries or agents were involved? It can help explain *why a task was usage-heavy*. It cannot tell us whether that work was worth doing without an outcome.

## Work backward from the decision

| Decision we want to make | Evidence we need first |
| --- | --- |
| Are costs rising? | Billing trend, contract changes, seats/allowances and usage period |
| What may be driving usage? | Model-call input/output/cache tokens, execution counts and task mix |
| Which usage is avoidable? | Comparable tasks, examples of friction, accepted outcomes and rework |
| Did a tooling change help? | Baseline/treatment runs, same quality bar, usage and wall time |
| Did delivery improve? | Team-level throughput, cycle time, review/rework and quality context |
| Was the investment worth it? | Financial spend plus defensible delivery benefit and operating cost |

For now, focus on the middle two questions: **what is driving usage, and what can we improve without making results worse?**

## Throughput belongs in the story—but label it carefully

We want throughput to be an early signal of AI impact. Relative to a future ROI calculation, it can be a useful input. Relative to an intervention, it is usually a downstream outcome, not a leading cause.

Faster PR creation is not the same as faster useful delivery. Pair it with review wait, rework, defects/reverts and task mix. A team can produce more PRs while burdening its reviewers or splitting work into smaller units.

For the pilot, put three views next to each other for the **same cohort and period**:

1. GitHub billed usage and coverage.
2. OTel usage patterns on opted-in, classified tasks.
3. LinearB throughput/cycle-time and quality context.

Add a short narrative: “We changed the test harness, saw fewer retry loops on the sampled tasks, and will watch delivery/rework before expanding.” Do not write “AI saved 20%” because two charts moved together. We have not connected to LinearB or imported billing in this lab.

## A few rules that keep us honest

Tokens, Copilot billing units, billed dollars and human time are different things. A larger input count is a technical clue, not an invoice calculation. Cache categories and model choice change how consumption should be interpreted.

Look at tasks, not engineer rankings. A long investigation may save a day of manual debugging. A short run may produce a bad answer. “Expensive” needs a comparator and an outcome.

Do not sum root usage and child model usage together. Count unique model spans once for token analysis. For execution sprawl, distinguish root interactions from child agents, and wall-clock time from overlapping child duration.

**Next:** [Walk through the synthetic cost demo](demo.md), then use [the pattern guide](catalog.md) to investigate real, approved examples.
