# Make one change, then see if it helped

**The point of analytics is a better workflow—not another weekly screenshot.** We want to spend less on avoidable friction while keeping useful outcomes. Eventually we will connect that to delivery and ROI.

## A small loop we can actually run

```text
Notice a pattern
  -> inspect a few examples
  -> state a hypothesis
  -> change one thing
  -> compare outcomes and usage
  -> keep, revise, or roll back
```

Start manually. We do not need an autonomous optimizer to learn whether a broken test integration is wasting calls.

## Example: fix the test setup tax

**What we saw:** Some bug-fix sessions repeatedly tried unavailable test runners. They had extra tool errors and model calls.

**Our hypothesis:** A repository-specific preflight will remove that setup loop without skipping required tests.

**One change:** Add a pinned test-running skill/tool that checks the package manager, runner and smallest appropriate target. Leave model routing and other instructions unchanged.

**The comparison:** Run the old and new workflow on the same approved task fixtures, with clean environments and known expected tests. Alternate the order where practical. Record failures, abandoned tasks and retries, not only successes.

**What would count as better:** Comparable accepted results with fewer setup errors, less rework and lower usage/wall time. Decide the quality bar and what counts as a meaningful change *before* reviewing the results.

**What would disprove it:** The tool runs faster but chooses the wrong test target. Or it works only in one unusually simple repository. Those are reasons to revise or reject it—not hide the bad examples.

## Keep an experiment card, not a giant report

Put this in a private tracker:

| Field | Example |
| --- | --- |
| Question | Can preflight reduce avoidable runner retries? |
| Task class | Test-backed bug fix |
| Old/new versions | baseline / test-preflight-v1 |
| Evidence | Approved fixtures, trace links, runtime/model versions |
| Quality bar | Required tests pass; reviewer accepts the fix |
| Usage measures | Unique chat tokens, invocation shape, wall time |
| Guardrails | No extra rework or policy failures |
| Result | Keep / revise / rollback / inconclusive |

Include sample size, missing capture, unknown outcomes and a counterexample. Do not invent a percentage target from a vendor case study.

## Connect this to the managers' view

Managers already use LinearB dashboards, so bring those into the discussion. Use the same team/cohort and calendar window as billing, while being clear that only a subset of work may have local traces.

The story should have three parts: **what changed in tooling, what changed inside sampled tasks, and what happened to delivery/rework afterward**.

Throughput is one signal we want to improve. Pair it with cycle time, review load, defects/reverts and task mix. A before/after change is not automatic causal proof: staffing, release timing and task difficulty also move those numbers.

Do not join a person's Git activity to an OTel session just because timestamps are close. Use approved explicit task links or cohort-level reporting, and disclose the coverage gap. This lab has no billing/LinearB ingestion yet.

## A weekly review can stay short

Spend a few minutes checking coverage and privacy. Review one typical example, one outlier and one case that challenges the theory. Pick one intervention with an owner and a rollback version. Decide last week's experiment: keep, revise, stop, or gather more evidence.

Let participants explain the work. “That long session saved a day of debugging” is important evidence a token chart does not contain.

## Where agents help

Agents can summarize a selected trace, find recurring patterns in bounded data, draft a tooling change, or prepare an experiment comparison. They should cite span IDs and show uncertainty—not infer intent or productivity from usage.

Start read-only. Keep a human in charge of budgets, model policies and rollout decisions. Captured text is untrusted data, never an instruction to the analyst. See [copyable analysis prompts and local MCP options](agent-analysis.md).

## The cultural goal

Share lessons like “our test integration caused retries” or “scoped retrieval helped this task class.” Avoid engineer leaderboards and blanket token caps.

Make the reliable path easy to use: a good repository map, deterministic setup, a working test tool, clear worker scopes and well-tested skills. Reward useful outcomes and honest failed hypotheses, not high AI activity.

**Our first milestone:** Explain a repeatable cost driver and improve it on a small cohort. **Later:** reconcile usage with billing, watch delivery guardrails, and build a defensible ROI model. Do not skip the middle steps.
