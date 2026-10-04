# Useful insights, evidence and gaps

**The first insights should fix recurring tool/workflow friction, not assign individual productivity scores.** This catalog distinguishes what OTel directly measures from what we have to infer or label.

## The highest-value starting questions

| Insight | OTel evidence | Missing evidence / caveat | Intervention to test |
| --- | --- | --- | --- |
| Tool reliability bottleneck | Tool counts, status/error, duration; MCP connection outcomes | Successful tools can return wrong/useless data | Preflight auth/schema; repair a flaky integration |
| Repeated execution loop | Ordered tool/model spans and repeated tool names | Repetition alone is not waste; arguments/content may be unavailable | Narrow the plan, improve command selection, add a loop guard |
| Context churn | Input token trajectory, compaction/truncation events | Complexity may justify long context; events vary by runtime | Repository map, scoped retrieval, task-state summary |
| Latency concentration | Chat/tool timing and streaming first-chunk fields | Human wait time and concurrent work complicate totals | Remove repeated setup or slow integration calls |
| Model routing mismatch | Requested/resolved model, usage, task class | Cheaper models may reduce correctness; Auto behavior can change | Evaluate fixed configurations on the same task fixtures |
| Skill friction or benefit | Skill invocation events, bundle version, tool outcomes | Invocation proves usage, not effectiveness | Versioned skill change with baseline/treatment tasks |
| Poor value per accepted task | Chat tokens/root AI units joined to outcomes | Unknown outcomes and incomplete billing coverage | Improve verification/retrieval before enforcing budgets |
| Environment setup tax | Repeated dependency/build/test setup spans | Shell commands may lack normalized categories | Deterministic setup tool or reusable development environment |

## First five views

**1. Tool health.** Failure proportion and duration distribution by tool category/version. Show completed calls, failed calls and unknown status separately. Distinguish agent misuse from unavailable credentials or an unstable MCP service.

**2. Interaction shape.** Model-call/tool-call counts per root interaction and task class. High tails deserve inspection; medians conceal the long sessions experienced by heavy users.

**3. Context pressure.** Input token trajectory and compaction/truncation occurrence by task class. Separate total consumed input tokens across calls from the size of the latest context; repeated history can increase consumption without increasing the final context window.

**4. Outcome-conditioned usage.** Chat token totals and root AI units by accepted/partial/rejected/abandoned/unknown tasks. Keep unknowns visible. A task may span several sessions; add a private explicit task-to-session link rather than guessing by time.

**5. Tooling comparison.** Baseline versus a pinned instruction/skill/tool bundle on comparable tasks. Show outcome, rework, latency and usage together, plus client/model versions and capture coverage.

## Concrete query recipes

These are backend-independent query specifications, not executable PromQL or OpenSearch DSL. Use the [normalized records](../proposals/viewer.md) to implement them consistently.

| Question | Filter / grouping | Computation and interpretation |
| --- | --- | --- |
| Which tool causes repeated failures? | Unique `execute_tool` spans; group tool name + bundle version | Failed completed calls divided by calls with known status; show unknown count |
| How token-heavy is an accepted bug fix? | Labeled accepted bug-fix tasks; unique chat spans associated with each task | Sum input/output separately per task, then report median/p90 and sample size |
| Where does latency come from? | Root interactions; child operation intervals | Report wall-clock latency and operation distributions; do not sum overlapping children into wall time |
| Is compaction more common after a change? | Sessions with known event coverage; bundle version + task class | Sessions with at least one compaction divided by eligible sessions; label incomplete event coverage |
| Did a skill reduce repair loops? | Comparable task fixtures; baseline vs treatment | Review sequence pattern plus acceptance/rework; counts alone cannot establish waste |
| How much Copilot usage was consumed? | Unique top-level root invocations with billing field | Sum `github.copilot.nano_aiu`, convert to AI units; report missing values and no currency claim |

For acceptance proportion, use tasks with a known completed outcome and show excluded unknown/abandoned cases. Also report abandonment separately so a treatment cannot “improve” by dropping difficult tasks from the denominator.

## Example: a repeated test-command failure

Suppose several sessions repeatedly call an unavailable test runner before finding the right command. Metadata shows failed tool spans, extra model calls and long interactions. The participant confirms environment discovery was the problem.

Change one repository skill to select the supported package manager and test command deterministically. Compare equivalent tasks using the old/new skill. Success means accepted results with less environment friction, not simply fewer tool calls. Keep a counterexample where discovery is genuinely necessary.

This is a strong early insight because the intervention addresses a concrete integration defect. “You should write better prompts” is usually weaker and harder to evaluate.

## Example: context churn

Suppose long investigations repeatedly compact and reload broad directory content. Inspect a typical successful investigation as a comparator. The problem may be poor retrieval scope, not the model.

Test a repository-navigation tool or a structured progress summary. If the treatment uses fewer input tokens but misses required evidence or creates more rework, reject it. Content-free metadata can locate candidates; approved examples or user feedback are often needed to understand why.

## Cost: keep four ledgers separate

| Ledger | Source | Correct interpretation |
| --- | --- | --- |
| Token usage | Unique model-call spans or correctly aggregated metrics | Technical consumption, with provider-specific cache semantics |
| Copilot AI units / multipliers | Runtime billing attributes | Usage units/multipliers, not currency |
| Actual billed spend | GitHub billing/usage exports and plan terms | Financial truth, reconcile on an appropriate time/account grain |
| Total workflow cost | Spend + infrastructure + human rework evidence | Decision support, with explicit assumptions and uncertainty |

For BYOK, a versioned provider rate card can estimate inference cost if the emitted token categories map correctly. Label the result “estimated,” include the rate date, and reconcile to provider billing. Do not use a generic public token price to estimate Copilot invoice dollars.

## What requires an evaluation system?

Correctness, maintainability, security, policy compliance and usefulness cannot be inferred reliably from “span status OK.” Add task fixtures, deterministic checks and a human rubric. If using an LLM judge, calibrate against human judgments, version it and disclose disagreements; its score is not ground truth.

## Biases and false precision

High-volume volunteers are not representative of 1,000 engineers. Their tasks, model choices and skill differ. Compare within a task class and environment; avoid cross-team leaderboards.

Schema gaps, lost spans, sampling, incomplete sessions and missing outcome labels all bias totals. Report those gaps next to the chart. Treat changing model routing or runtime versions as confounders.

OTel reveals patterns worth investigating. The useful insight is **a testable intervention backed by examples**, not a chart annotation that sounds certain.

**Next:** [The improvement loop](improvement-loop.md).
